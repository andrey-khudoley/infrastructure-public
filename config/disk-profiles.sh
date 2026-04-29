# shellcheck shell=bash
#
# Матрица профилей разметки по размеру основного диска (шаг 40).
# Подключается из scripts/40-disk-storage.sh после scripts/lib/common.sh (нужен log_info).
#
# Границы по целому DISK_SIZE_G (GiB), см. resolve_disk_size_group в 40-disk-storage.sh.
#
# Диапазон GiБ | ROOT_TARGET_G | VAR_SIZE_G | MINIO_SIZE_G | SWAP_SIZE_G | VAR_MIN_FREE_MIB
# 2–20         | g−1           | 0          | 0            | 1           | 1024  (1 GiB под swap, остальное под корень)
# 21–30        | 16            | 0          | 0            | 1           | 1024
# 31–40        | 20            | 0          | 0            | 2           | 1024
# 41–50        | 24            | 8          | 0            | 2           | 1024
# 51–60        | 26            | 12         | 0            | 2           | 1024
# 61–70        | 28            | 15         | 0            | 2           | 1024
# 71–80        | 30            | 18         | 0            | 4           | 1024
# 81–90        | 30            | 20         | 15           | 4           | 1024
# 91–100       | 30            | 24         | 20           | 4           | 1024
# 101–110      | 32            | 28         | 25           | 4           | 1024
# 111–120      | 35            | 30         | 30           | 4           | 1024
# свыше 120    | 40            | 35         | 35           | 4           | 1024
#
# Отключить: DISK_PROFILE_USE_MATRIX=0 (остаются только узловой профиль и apply_disk_defaults).

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

  if (( g >= 2 && g <= 20 )); then
    SWAP_SIZE_G=1
    ROOT_TARGET_G=$((g - 1))
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
  elif (( g < 2 )); then
    log_warn "Диск <2 GiB по DISK_SIZE_G=${g}: минимальный профиль матрицы (корень без выделенного swap в профиле)."
    ROOT_TARGET_G=1
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=0
  elif (( g <= 30 )); then
    ROOT_TARGET_G=16
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=1
  elif (( g <= 40 )); then
    ROOT_TARGET_G=20
    VAR_SIZE_G=0
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 50 )); then
    ROOT_TARGET_G=24
    VAR_SIZE_G=8
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 60 )); then
    ROOT_TARGET_G=26
    VAR_SIZE_G=12
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 70 )); then
    ROOT_TARGET_G=28
    VAR_SIZE_G=15
    MINIO_SIZE_G=0
    SWAP_SIZE_G=2
  elif (( g <= 80 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=18
    MINIO_SIZE_G=0
    SWAP_SIZE_G=4
  elif (( g <= 90 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=20
    MINIO_SIZE_G=15
    SWAP_SIZE_G=4
  elif (( g <= 100 )); then
    ROOT_TARGET_G=30
    VAR_SIZE_G=24
    MINIO_SIZE_G=20
    SWAP_SIZE_G=4
  elif (( g <= 110 )); then
    ROOT_TARGET_G=32
    VAR_SIZE_G=28
    MINIO_SIZE_G=25
    SWAP_SIZE_G=4
  elif (( g <= 120 )); then
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
