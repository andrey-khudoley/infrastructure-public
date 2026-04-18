# shellcheck shell=bash
# Проверка root, dnf, базовых утилит.

require_runtime() {
  [[ "${EUID}" -eq 0 ]] || fail "Скрипт должен запускаться от root."
  has_cmd dnf || fail "Не найден dnf. Скрипт рассчитан на dnf-совместимые дистрибутивы."

  for cmd in lsblk findmnt awk sed blkid mount umount; do
    has_cmd "$cmd" || fail "Не найдена обязательная утилита: ${cmd}"
  done
}

step_require_runtime() {
  require_runtime
}
