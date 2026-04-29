# shellcheck shell=bash
#
# Матрица профилей разметки по размеру основного диска (декады: 20–29, 30–39, …).
# Подключается из scripts/20-disk-storage.sh после scripts/lib/common.sh (нужен log_info).
#
# Границы по целому DISK_SIZE_G (GiB), см. resolve_disk_size_group в 20-disk-storage.sh.
#
# Диапазон GiБ | ROOT_TARGET_G | VAR_SIZE_G | MINIO_SIZE_G | SWAP_SIZE_G | VAR_MIN_FREE_MIB
# 2–19         | g−1           | 0          | 0            | 1           | 1024  (1 GiB под swap, остальное под корень)
# 20–29        | 16            | 0          | 0            | 1           | 1024
# 30–39        | 20            | 0          | 0            | 2           | 1024
# 40–49        | 24            | 8          | 0            | 2           | 1024
# 50–59        | 26            | 12         | 0            | 2           | 1024
# 60–69        | 28            | 15         | 0            | 2           | 1024
# 70–79        | 30            | 18         | 0            | 4           | 1024
# 80–89        | 30            | 20         | 15           | 4           | 1024
# 90–99        | 30            | 24         | 20           | 4           | 1024
# 100–109      | 32            | 28         | 25           | 4           | 1024
# 110–119      | 35            | 30         | 30           | 4           | 1024
# 120 и выше   | 40            | 35         | 35           | 4           | 1024
#
# Отключить: DISK_PROFILE_USE_MATRIX=0 (остаются только узловой профиль и apply_disk_defaults).
#
# После разметки по таблице (root до ROOT_TARGET_G, при необходимости LV /var и /minio) весь оставшийся свободный объём в VG добавляется к корню — expand_root_lv_consume_vg_free в scripts/20-disk-storage.sh.

# Выставляет ROOT_TARGET_G, VAR_SIZE_G, MINIO_SIZE_G, SWAP_SIZE_G, VAR_MIN_FREE_MIB по DISK_SIZE_G.
#
# @globals DISK_PROFILE_USE_MATRIX DISK_SIZE_G ROOT_TARGET_G VAR_SIZE_G MINIO_SIZE_G SWAP_SIZE_G VAR_MIN_FREE_MIB
# @return 0
apply_disk_profile_matrix() {
  [[ "${DISK_PROFILE_USE_MATRIX:-1}" == "1" ]] || return 0

  local g="${DISK_SIZE_G:-}"
  if [[ -z "$g" ]] || ! [[ "$g" =~ ^[0-9]+$ ]]; then
    log_warn "DISK_SIZE_G не определён — профиль по матрице не применён."
    return 0
  fi

  if (( g < 2 )); then
    log_warn "Диск <2 GiB по DISK_SIZE_G=${g}: минимальный профиль матрицы (корень без выделенного swap в профиле)."
    ROOT_TARGET_G=1
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=0
  elif (( g >= 2 && g <= 19 )); then
    SWAP_SIZE_G=1
    ROOT_TARGET_G=$((g - 1))
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
  elif (( g <= 29 )); then
    ROOT_TARGET_G=16
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=1
  elif (( g <= 39 )); then
    ROOT_TARGET_G=20
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 49 )); then
    ROOT_TARGET_G=24
    VAR_SIZE_G=8
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 59 )); then
    ROOT_TARGET_G=26
    VAR_SIZE_G=12
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 69 )); then
    ROOT_TARGET_G=28
    VAR_SIZE_G=15
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 79 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=18
    MINIO_SIZE_G=0
    SWAP_SIZE_G=4
  elif (( g <= 89 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=20
    MINIO_SIZE_G=15
    SWAP_SIZE_G=4
  elif (( g <= 99 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=24
    MINIO_SIZE_G=20
    SWAP_SIZE_G=4
  elif (( g <= 109 )); then
    ROOT_TARGET_G=32
    VAR_SIZE_G=28
    MINIO_SIZE_G=25
    SWAP_SIZE_G=4
  elif (( g <= 119 )); then
    ROOT_TARGET_G=35
    VAR_SIZE_G=30
    MINIO_SIZE_G=30
    SWAP_SIZE_G=4
  else
    ROOT_TARGET_G=40
    VAR_SIZE_G=35
    MINIO_SIZE_G=35
    SWAP_SIZE_G=4
  fi

  VAR_MIN_FREE_MIB=1024

  log_info "Матрица профилей: диск ~${g}G → ROOT_TARGET_G=${ROOT_TARGET_G} VAR_SIZE_G=${VAR_SIZE_G} MINIO_SIZE_G=${MINIO_SIZE_G} SWAP_SIZE_G=${SWAP_SIZE_G} VAR_MIN_FREE_MIB=${VAR_MIN_FREE_MIB}"
}
