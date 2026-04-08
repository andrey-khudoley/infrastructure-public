# shellcheck shell=bash
# Логирование, dnf, git, проверки sshd/NM, require_runtime, deploy key.

log_info() { echo "[+] $*"; }
log_warn() { echo "[!] $*"; }
log_err() { echo "[x] $*" >&2; }

section() { echo; echo "== $* =="; }

fail() {
  log_err "$*"
  exit 1
}

has_cmd() { command -v "$1" &>/dev/null; }

git_repo() {
  git -c credential.helper= "$@"
}

repo_url_is_ssh() {
  [[ "${REPO_URL}" == git@* ]] || [[ "${REPO_URL}" == ssh://* ]]
}

dnf_install() {
  [[ "$#" -gt 0 ]] || return 0
  dnf install -y "$@"
}

distro_sync_system() {
  section "Синхронизация с репозиториями (distro-sync)"
  log_info "dnf distro-sync — полное выравнивание системы с доступными репозиториями."
  dnf distro-sync -y
}

verify_sshd() {
  local sshd_bin=""
  if [[ -x /usr/sbin/sshd ]]; then
    sshd_bin=/usr/sbin/sshd
  elif has_cmd sshd; then
    sshd_bin=$(command -v sshd)
  else
    fail "Не найден бинарник sshd (/usr/sbin/sshd), удалённая администрация недоступна."
  fi

  log_info "Проверка sshd (конфигурация и совместимость OpenSSL)…"
  "${sshd_bin}" -t || fail "sshd -t не прошёл (в т.ч. возможный OpenSSL mismatch). Проверьте dnf/rpm."

  if systemctl cat sshd.service &>/dev/null; then
    systemctl enable sshd.service 2>/dev/null || true
    systemctl start sshd.service 2>/dev/null || true
    systemctl is-active --quiet sshd.service || fail "sshd.service не в состоянии active после запуска."
  else
    log_warn "Unit sshd.service не найден; проверка active пропущена (только sshd -t)."
  fi
}

verify_network_stack_if_managed() {
  if systemctl list-unit-files NetworkManager.service &>/dev/null; then
    if systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
      log_info "Проверка NetworkManager (enabled)…"
      systemctl is-active --quiet NetworkManager.service || fail "NetworkManager не active — сеть может быть недоступна."
    fi
  fi
}

verify_critical_services() {
  section "Критичные сервисы"
  verify_sshd
  verify_network_stack_if_managed
  log_info "Критичные проверки пройдены."
}

ensure_infra_deploy_key() {
  repo_url_is_ssh || return 0

  section "SSH-ключ для репозитория (deploy key)"
  if ! has_cmd ssh-keygen; then
    dnf_install openssh-clients
  fi

  install -d -m 0700 "$(dirname "${INFRA_SSH_KEY}")"

  if [[ -f "${INFRA_SSH_KEY}" ]]; then
    log_info "Ключ уже существует (${INFRA_SSH_KEY}), новый не создаём."
  else
    log_info "Создаём ключ: ${INFRA_SSH_KEY} (${INFRA_SSH_KEY_COMMENT})"
    ssh-keygen -q -t ed25519 -N "" -C "${INFRA_SSH_KEY_COMMENT}" -f "${INFRA_SSH_KEY}"
    chmod 600 "${INFRA_SSH_KEY}" 2>/dev/null || true
    echo
    log_info "Публичный ключ — добавьте его в Deploy keys (read-only) репозитория:"
    echo
    cat "${INFRA_SSH_KEY}.pub"
    echo
    if [[ "${INFRA_SSH_SKIP_PROMPT}" != "1" ]]; then
      read -r -p "После добавления ключа нажмите Enter для продолжения… " _
    fi
  fi

  export GIT_SSH_COMMAND="ssh -i \"${INFRA_SSH_KEY}\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
}

require_runtime() {
  [[ "${EUID}" -eq 0 ]] || fail "Скрипт должен запускаться от root."
  has_cmd dnf || fail "Не найден dnf. Скрипт рассчитан на dnf-совместимые дистрибутивы."

  for cmd in lsblk findmnt awk sed blkid mount umount; do
    has_cmd "$cmd" || fail "Не найдена обязательная утилита: ${cmd}"
  done
}
