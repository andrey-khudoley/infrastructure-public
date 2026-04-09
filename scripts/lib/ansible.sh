# shellcheck shell=bash
# Клон репозитория и ansible-pull stage1. Требует common.sh (git_repo, fail, section, log_*).

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

run_stage1_ansible_pull() {
  section "Первый запуск stage1"
  local run="${PULL_DIR}/run.sh"
  [[ -f "${run}" ]] || fail "Не найден ${run}. В корне приватного репозитория должен быть run.sh (обёртка над make, цель stage1-pull)."
  chmod +x "${run}" 2>/dev/null || true
  (
    cd "${PULL_DIR}"
    export REPO_URL="${REPO_URL}"
    export REF="${REF_VALUE}"
    export ENV="${ENV_VALUE}"
    export PULL_DIR="${PULL_DIR}"
    ./run.sh stage1-pull
  )
}
