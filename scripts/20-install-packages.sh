# shellcheck shell=bash
# EPEL, git, ansible-core, make (для run.sh / make install-deps в приватном репо).

install_base_packages() {
  section "Установка пакетов"
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    dnf_install epel-release git curl parted
  else
    dnf_install epel-release git curl ansible-core parted make
  fi
}

step_install_packages() {
  install_base_packages
  distro_sync_system
}
