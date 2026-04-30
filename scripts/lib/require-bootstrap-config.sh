# shellcheck shell=bash
#
# Проверка наличия рабочих config/*.env после make init (infrastructure-public).
# ROOT и fail() должны быть доступны (run-start.sh / run-update.sh после common.sh).

# @return 0 если файлы на месте; иначе fail()
require_bootstrap_config_files() {
  local f
  for f in host.env repos.env ssh.env galaxy.env; do
    [[ -f "${ROOT}/config/${f}" ]] || fail "Нет config/${f}. В корне клона выполните: make init"
  done
}
