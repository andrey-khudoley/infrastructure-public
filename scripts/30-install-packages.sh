# shellcheck shell=bash
#
# Шаг 30 — базовые пакеты и выравнивание репозиториев (distro-sync).
#
# Единый контур Ansible: ansible-core и коллекции ставятся в приватном репо из
# constraints.txt (scripts/install-python-deps.sh) и collections/requirements.yml
# (scripts/galaxy-offline-install.sh), поэтому здесь НЕ ставим ansible-core из
# dnf — чтобы не получить две разные версии в PATH. Python >= 3.12 при
# необходимости ставит install-python-deps.sh сам через dnf.
#
# При SKIP_ANSIBLE=1 не ставим make — только то, что нужно для git/дисков.
# Иначе: make — для целей «install-deps» и «bootstrap» приватного Makefile.

# Устанавливает пакеты через dnf в зависимости от SKIP_ANSIBLE, затем выводит секцию в лог.
#
# @globals SKIP_ANSIBLE  при «1» — урезанный набор без make
# @return 0
install_base_packages() {
  section "Установка пакетов"
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    dnf_install epel-release git curl parted
  else
    dnf_install epel-release git curl parted make
  fi
}

# Шаг 30: пакеты и первый distro-sync (второй — в шаге 90).
#
# @return 0
step_install_packages() {
  install_base_packages
  distro_sync_system
}
