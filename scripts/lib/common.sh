# shellcheck shell=bash
#
# Общие утилиты для шагов start.sh (подключается сразу после env.sh).
#
# git_repo — обёртка над git с отключённым credential.helper, чтобы clone/fetch по HTTPS
# не блокировались интерактивным запросом пароля в неинтерактивном bootstrap.
# dnf_install / distro_sync_system — единообразные вызовы dnf для шагов 20 и 90.

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

dnf_install() {
  [[ "$#" -gt 0 ]] || return 0
  dnf install -y "$@"
}

distro_sync_system() {
  section "Синхронизация с репозиториями (distro-sync)"
  log_info "dnf distro-sync — полное выравнивание системы с доступными репозиториями."
  dnf distro-sync -y
}
