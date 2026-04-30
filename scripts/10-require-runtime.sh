# shellcheck shell=bash
#
# Шаг 10 — минимальные предусловия для остальных шагов.
# Нужен root (модификация дисков, dnf), менеджер пакетов dnf и утилиты для шага 20.

# Проверяет, что среда подходит для bootstrap: UID 0, dnf, утилиты для дисков.
#
# @return 0 если все проверки пройдены
# @exit   ненулевой код через fail() при нарушении условий
require_runtime() {
  [[ "${EUID}" -eq 0 ]] || fail "Скрипт должен запускаться от root."
  has_cmd dnf || fail "Не найден dnf. Скрипт рассчитан на dnf-совместимые дистрибутивы."

  for cmd in lsblk findmnt awk sed blkid mount umount; do
    has_cmd "$cmd" || fail "Не найдена обязательная утилита: ${cmd}"
  done
}

# Точка входа шага 10 для make start (scripts/run-start.sh).
#
# @return 0
step_require_runtime() {
  require_runtime
  require_bootstrap_config_files
}
