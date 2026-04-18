# shellcheck shell=bash
#
# Шаг 20 — базовые пакеты и выравнивание репозиториев (distro-sync).
# При SKIP_ANSIBLE=1 не ставим ansible-core и make — только то, что нужно для git/дисков.
# Иначе: ansible-core для ansible-playbook в приватном репо, make — для «make start».

# Устанавливает пакеты через dnf в зависимости от SKIP_ANSIBLE, затем выводит секцию в лог.
#
# @globals SKIP_ANSIBLE  при «1» — урезанный набор без ansible-core и make
# @return 0
install_base_packages() {
  section "Установка пакетов"
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    dnf_install epel-release git curl parted
  else
    dnf_install epel-release git curl ansible-core parted make
  fi
}

# Шаг 20: пакеты и первый distro-sync (второй — в шаге 90).
#
# @return 0
step_install_packages() {
  install_base_packages
  distro_sync_system
}
