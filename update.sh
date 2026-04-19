#!/usr/bin/env bash
#
# Обновление клона публичного репозитория и синхронизация приватного (только git).
# Ansible, make и start.sh не вызываются.
#
# Запуск из корня клона infrastructure-public (рядом с этим файлом):
#   sudo bash update.sh
#
# Конфигурация: корневой .env — PUBLIC_REPO_URL, PUBLIC_REF, REPO_URL, REF, PULL_DIR.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/load-env.sh
source "${ROOT}/scripts/lib/load-env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=scripts/50-sync-repository.sh
source "${ROOT}/scripts/50-sync-repository.sh"

sync_public_repository() {
  section "Публичный репозиторий"
  [[ -n "${PUBLIC_REPO_URL:-}" ]] || fail "Задайте PUBLIC_REPO_URL в .env или окружении."

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

sync_public_repository
sync_repository

log_info "Готово: публичный репозиторий на ${PUBLIC_REF_VALUE}, приватный — ${PULL_DIR} (${REF_VALUE})."
