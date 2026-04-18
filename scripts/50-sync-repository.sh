# shellcheck shell=bash
#
# Шаг 50 — приватный репозиторий с плейбуками в PULL_DIR.
# Если каталог уже есть — fetch + checkout на REF_VALUE; иначе clone -b REF_VALUE.
# Перед шагом 70 в корне клона должен появиться Makefile (цель start) — это проверяется в 70.

# Синхронизирует клон приватного репозитория: clone или fetch/checkout.
#
# @globals REPO_URL REF_VALUE PULL_DIR
# @return 0 при успехе git-операций
sync_repository() {
  section "Репозиторий"
  log_info "Синхронизация ${REPO_URL} (${REF_VALUE}) -> ${PULL_DIR}"
  install -d -m 0755 "$(dirname "${PULL_DIR}")"

  if [[ -d "${PULL_DIR}/.git" ]]; then
    (
      cd "${PULL_DIR}"
      if git remote get-url origin &>/dev/null; then
        prev=$(git remote get-url origin)
        if [[ "${prev}" != "${REPO_URL}" ]]; then
          log_warn "origin был ${prev}, выставляем ${REPO_URL} (как в REPO_URL)."
        fi
        git_repo remote set-url origin "${REPO_URL}"
      else
        git_repo remote add origin "${REPO_URL}"
      fi
      git_repo fetch origin "${REF_VALUE}"
      git_repo checkout "${REF_VALUE}"
    )
  else
    git_repo clone -b "${REF_VALUE}" "${REPO_URL}" "${PULL_DIR}"
  fi
}

# Обёртка шага 50 с учётом SKIP_ANSIBLE.
#
# @globals SKIP_ANSIBLE
# @return 0; при SKIP_ANSIBLE=1 — ранний выход без clone
step_sync_repository() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: синхронизация репозитория пропущена."
    return 0
  fi
  sync_repository
}
