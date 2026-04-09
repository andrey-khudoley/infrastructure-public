# shellcheck shell=bash
# Первый ansible-pull с тегом stage1: в клоне вызывается ./run.sh stage1-pull → make stage1-pull.

step_ansible_pull_stage1() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: ansible-pull пропущен."
    return 0
  fi
  run_stage1_ansible_pull
}
