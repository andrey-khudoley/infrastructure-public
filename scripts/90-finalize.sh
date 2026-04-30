# shellcheck shell=bash
#
# Шаг 90 — после пакетов и «make install-deps» повторный distro-sync, смоук-тесты
# критичных сервисов, интерактивное «make update-sysuser» в корне клона и только
# затем итоговая подсказка с командой запуска stage1 вручную.
# Никаких systemd-юнитов и автоматических переходов; stage1/stage2/runtime
# запускаются пользователем через make в корне клона.

# Проверяет конфигурацию sshd и доступность сервиса после обновлений пакетов.
#
# @return 0 при успешных проверках
# @exit   через fail при критичных ошибках sshd
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

# Если NetworkManager включён в systemd — проверяет, что он active.
#
# @return 0
# @exit   через fail, если NM enabled, но не active
verify_network_stack_if_managed() {
  if systemctl list-unit-files NetworkManager.service &>/dev/null; then
    if systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
      log_info "Проверка NetworkManager (enabled)…"
      systemctl is-active --quiet NetworkManager.service || fail "NetworkManager не active — сеть может быть недоступна."
    fi
  fi
}

# Последовательно: sshd, затем NetworkManager при необходимости.
#
# @return 0
verify_critical_services() {
  section "Критичные сервисы"
  verify_sshd
  verify_network_stack_if_managed
  log_info "Критичные проверки пройдены."
}

# Вызывает «make update-sysuser» в каталоге клона (интерактивно: имя и пароль
# администратора в vars/all.yml). Подсказка про stage1 выводится только после
# этого шага.
#
# @globals PULL_DIR REPO_URL REF_VALUE ENV_VALUE
# @return код возврата make update-sysuser
# @exit   через fail, если нет Makefile
run_update_sysuser() {
  section "Системный администратор: make update-sysuser"
  local mk="${PULL_DIR}/Makefile"
  [[ -f "${mk}" ]] || fail "Не найден ${mk}. В корне приватного репозитория должен быть Makefile (цель update-sysuser)."
  (
    cd "${PULL_DIR}"
    export REPO_URL="${REPO_URL}"
    export REF="${REF_VALUE}"
    export ENV="${ENV_VALUE}"
    export PULL_DIR="${PULL_DIR}"
    make update-sysuser
  )
}

# Печатает итоговую подсказку с командой запуска stage1 вручную.
#
# @globals PULL_DIR ENV_VALUE SKIP_ANSIBLE
# @return 0
print_next_step_hint() {
  section "Следующий шаг — stage1 (вручную)"
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: установите зависимости вручную и запустите stage1:"
    echo "    cd ${PULL_DIR}"
    echo "    sudo make init"
    echo "    sudo make install-deps"
    echo "    sudo make stage1 ENV=${ENV_VALUE}"
  else
    log_info "Подготовка завершена. Разверните config из шаблонов и запустите фазу stage1:"
    echo "    cd ${PULL_DIR}"
    echo "    sudo make init"
    echo "    sudo make stage1 ENV=${ENV_VALUE}"
  fi
  echo
  log_info "Дальше stage1 сам подскажет команду для stage2 (и при необходимости перезагрузит сервер)."
}

# Финальный distro-sync, проверки сервисов и итоговая подсказка.
#
# @return 0
step_finalize() {
  distro_sync_system
  verify_critical_services
  run_update_sysuser
  print_next_step_hint
}
