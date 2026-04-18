# shellcheck shell=bash
# Первый ansible-pull с тегом stage1: в клоне вызывается ./run.sh stage1-pull → make stage1-pull.

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

step_ansible_pull_stage1() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: ansible-pull пропущен."
    return 0
  fi
  run_stage1_ansible_pull
}
