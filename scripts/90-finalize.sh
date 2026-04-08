# shellcheck shell=bash
# Финальный distro-sync и проверка sshd / NetworkManager.

step_finalize() {
  distro_sync_system
  verify_critical_services

  section "Готово"
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "Bootstrap завершён (без Ansible stage1)."
  else
    log_info "Stage-1 выполнен успешно."
  fi
}
