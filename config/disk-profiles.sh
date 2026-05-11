# shellcheck shell=bash
#
# Матрица профилей разметки по размеру основного диска (декады: 20–29, 30–39, …).
# Подключается из scripts/20-disk-storage.sh после scripts/lib/common.sh (нужен log_info).
#
# Границы по целому DISK_SIZE_G (GiB), см. resolve_disk_size_group в 20-disk-storage.sh.
#
# Диапазон GiБ | ROOT_TARGET_G | VAR_SIZE_G | MINIO_SIZE_G | SWAP_SIZE_G | VAR_MIN_FREE_MIB
# 2            | 1             | 0          | 0            | 1           | 1024
# 3–19         | g−2           | 0          | 0            | 2           | 1024
# 20–29        | 15            | 0          | 0            | 2           | 1024
# 30–39        | 18            | 0          | 0            | 4           | 1024
# 40–49        | 22            | 8          | 0            | 4           | 1024
# 50–59        | 24            | 12         | 0            | 4           | 1024
# 60–69        | 26            | 15         | 0            | 4           | 1024
# 70–79        | 26            | 18         | 0            | 8           | 1024
# 80–89        | 26            | 20         | 15           | 8           | 1024
# 90–99        | 26            | 24         | 20           | 8           | 1024
# 100–109      | 28            | 28         | 25           | 8           | 1024
# 110–119      | 31            | 30         | 30           | 8           | 1024
# 120 и выше   | 36            | 35         | 35           | 8           | 1024
#
# Отключить: DISK_PROFILE_USE_MATRIX=0 (остаются только config/disk.env и apply_disk_defaults).
#
# Значения из матрицы не перезаписывают переменные, уже заданные в окружении (в т.ч. из
# config/disk.env, подключённого в scripts/lib/load-env.sh до шага 20).
#
# После разметки по таблице (root до ROOT_TARGET_G, при необходимости LV /var и /minio) весь оставшийся свободный объём в VG добавляется к корню — expand_root_lv_consume_vg_free в scripts/20-disk-storage.sh.

# Значение переменной профиля только если она ещё не задана (например, в config/disk.env).
#
# @param $1  имя переменной
# @param $2  значение по матрице
# @return 0
_matrix_var_if_unset() {
  local n="$1" v="$2"
  [[ -n ${!n+x} ]] && return 0
  printf -v "${n}" '%s' "${v}"
}

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
    _matrix_var_if_unset ROOT_TARGET_G 1
    _matrix_var_if_unset VAR_SIZE_G 0
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 0
  elif (( g == 2 )); then
    # 2 GiB: удвоить swap нельзя без нулевого корня — оставляем 1/1.
    _matrix_var_if_unset SWAP_SIZE_G 1
    _matrix_var_if_unset ROOT_TARGET_G 1
    _matrix_var_if_unset VAR_SIZE_G 0
    _matrix_var_if_unset MINIO_SIZE_G 0
  elif (( g >= 3 && g <= 19 )); then
    _matrix_var_if_unset SWAP_SIZE_G 2
    _matrix_var_if_unset ROOT_TARGET_G $((g - 2))
    _matrix_var_if_unset VAR_SIZE_G 0
    _matrix_var_if_unset MINIO_SIZE_G 0
  elif (( g <= 29 )); then
    _matrix_var_if_unset ROOT_TARGET_G 15
    _matrix_var_if_unset VAR_SIZE_G 0
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 2
  elif (( g <= 39 )); then
    _matrix_var_if_unset ROOT_TARGET_G 18
    _matrix_var_if_unset VAR_SIZE_G 0
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 4
  elif (( g <= 49 )); then
    _matrix_var_if_unset ROOT_TARGET_G 22
    _matrix_var_if_unset VAR_SIZE_G 8
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 4
  elif (( g <= 59 )); then
    _matrix_var_if_unset ROOT_TARGET_G 24
    _matrix_var_if_unset VAR_SIZE_G 12
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 4
  elif (( g <= 69 )); then
    _matrix_var_if_unset ROOT_TARGET_G 26
    _matrix_var_if_unset VAR_SIZE_G 15
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 4
  elif (( g <= 79 )); then
    _matrix_var_if_unset ROOT_TARGET_G 26
    _matrix_var_if_unset VAR_SIZE_G 18
    _matrix_var_if_unset MINIO_SIZE_G 0
    _matrix_var_if_unset SWAP_SIZE_G 8
  elif (( g <= 89 )); then
    _matrix_var_if_unset ROOT_TARGET_G 26
    _matrix_var_if_unset VAR_SIZE_G 20
    _matrix_var_if_unset MINIO_SIZE_G 15
    _matrix_var_if_unset SWAP_SIZE_G 8
  elif (( g <= 99 )); then
    _matrix_var_if_unset ROOT_TARGET_G 26
    _matrix_var_if_unset VAR_SIZE_G 24
    _matrix_var_if_unset MINIO_SIZE_G 20
    _matrix_var_if_unset SWAP_SIZE_G 8
  elif (( g <= 109 )); then
    _matrix_var_if_unset ROOT_TARGET_G 28
    _matrix_var_if_unset VAR_SIZE_G 28
    _matrix_var_if_unset MINIO_SIZE_G 25
    _matrix_var_if_unset SWAP_SIZE_G 8
  elif (( g <= 119 )); then
    _matrix_var_if_unset ROOT_TARGET_G 31
    _matrix_var_if_unset VAR_SIZE_G 30
    _matrix_var_if_unset MINIO_SIZE_G 30
    _matrix_var_if_unset SWAP_SIZE_G 8
  else
    _matrix_var_if_unset ROOT_TARGET_G 36
    _matrix_var_if_unset VAR_SIZE_G 35
    _matrix_var_if_unset MINIO_SIZE_G 35
    _matrix_var_if_unset SWAP_SIZE_G 8
  fi

  _matrix_var_if_unset VAR_MIN_FREE_MIB 1024

  log_info "Матрица профилей: диск ~${g}G → ROOT_TARGET_G=${ROOT_TARGET_G} VAR_SIZE_G=${VAR_SIZE_G} MINIO_SIZE_G=${MINIO_SIZE_G} SWAP_SIZE_G=${SWAP_SIZE_G} VAR_MIN_FREE_MIB=${VAR_MIN_FREE_MIB}"
}
