#!/usr/bin/env bash
#
# Обновление клона публичного репозитория и синхронизация приватного (только git).
# Никаких systemd-юнитов больше нет: после `git pull` приватного клона
# применить изменения на узле — это вручную через `make stage1`/`make stage2`/
# `make runtime` в корне клона (см. README приватного репозитория).
#
# Запуск из корня клона infrastructure-public (рядом с этим файлом):
#   sudo bash update.sh
#
# Конфигурация: config/*.env — PUBLIC_REPO_URL, PUBLIC_REF, REPO_URL, REF, PULL_DIR, INFRA_SSH_*.
# Логика SSH как в start.sh (шаг 40): github.com HTTPS → git@…, deploy key, GIT_SSH_COMMAND.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/load-env.sh
source "${ROOT}/scripts/lib/load-env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=scripts/lib/require-bootstrap-config.sh
source "${ROOT}/scripts/lib/require-bootstrap-config.sh"

require_bootstrap_config_files
# shellcheck source=scripts/40-ssh-deploy-key.sh
source "${ROOT}/scripts/40-ssh-deploy-key.sh"
# shellcheck source=scripts/50-sync-repository.sh
source "${ROOT}/scripts/50-sync-repository.sh"

prepare_ssh_for_infra_repos

sync_public_repository() {
  section "Публичный репозиторий"
  [[ -n "${PUBLIC_REPO_URL:-}" ]] || fail "Задайте PUBLIC_REPO_URL в config/repos.env или окружении."

  log_info "Обновление ${ROOT} <- ${PUBLIC_REPO_URL} (${PUBLIC_REF_VALUE})"
  if [[ ! -d "${ROOT}/.git" ]]; then
    fail "Нет ${ROOT}/.git — update.sh только для git-клона (не архива)."
  fi

  (
    cd "${ROOT}"
    if git remote get-url origin &>/dev/null; then
      prev=$(git remote get-url origin)
      if [[ "${prev}" != "${PUBLIC_REPO_URL}" ]]; then
        log_warn "origin был ${prev}, выставляем ${PUBLIC_REPO_URL} (как в PUBLIC_REPO_URL)."
      fi
      git_repo remote set-url origin "${PUBLIC_REPO_URL}"
    else
      git_repo remote add origin "${PUBLIC_REPO_URL}"
    fi
    git_repo fetch origin "${PUBLIC_REF_VALUE}"
    git_repo checkout "${PUBLIC_REF_VALUE}"
  )
}

print_next_steps_hint() {
  section "Готово"
  log_info "Публичный репозиторий: ${PUBLIC_REF_VALUE}. Приватный: ${PULL_DIR} (${REF_VALUE})."
  log_info "Чтобы применить изменения на узле, выполните вручную в корне клона приватного репо:"
  echo "    cd ${PULL_DIR}"
  echo "    sudo make runtime ENV=${ENV_VALUE}"
  echo
  log_info "Для повторного прогона фаз bootstrap (после правок ролей stage1/stage2) — make stage1 / make stage2 в том же каталоге."
}

sync_public_repository
sync_repository
print_next_steps_hint
