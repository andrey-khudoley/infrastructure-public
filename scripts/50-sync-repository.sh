# shellcheck shell=bash
# Клон или fetch основного репозитория в PULL_DIR.

step_sync_repository() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: синхронизация репозитория пропущена."
    return 0
  fi
  sync_repository
}
