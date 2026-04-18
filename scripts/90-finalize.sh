# shellcheck shell=bash
# Финальный distro-sync и проверка sshd / NetworkManager.

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
