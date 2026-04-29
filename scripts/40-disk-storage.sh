# shellcheck shell=bash
#
# Шаг 40 — разметка и точки монтирования под инфраструктуру (LVM, отдельный /var, /minio).
# Параметры: DISK_VARS_*, MAIN_DISK_DEVICE, DISK_PROFILE_USE_MATRIX, матрица config/disk-profiles.sh (см. README).
# Зависит от scripts/lib/common.sh. Логика объёмная — смотрите имена функций ниже по файлу.

# Добавляет одну строку в /etc/fstab, если такой точной строки ещё нет.
#
# @param $1  полная строка fstab (UUID=…, mountpoint, fs, opts, dump, pass)
# @return 0
append_fstab_once() {
  local line="$1"
  [[ -n "$line" ]] || return 0
  if ! grep -qF "$line" /etc/fstab 2>/dev/null; then
    echo "$line" >> /etc/fstab
  fi
}

# Проверяет, что аргумент — неотрицательное целое (цифры).
#
# @param $1  строка для проверки
# @return 0 если совпадает с ^[0-9]+$, иначе 1
is_non_negative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# Убирает суффикс номера раздела у пути устройства (например /dev/sda3 → /dev/sda).
#
# @param $1  путь блочного устройства
# @stdout   базовый диск
disk_base_name() {
  local dev="$1"
  echo "$dev" | sed -E 's/p?[0-9]+$//'
}

# Определяет диск, на котором смонтирован корень / (по цепочке findmnt → lsblk).
#
# @stdout путь вида /dev/… к диску
# @return 0 если диск найден, 1 если определить не удалось
detect_root_base_disk() {
  local root_source root_real parent_kname

  root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  root_real=$(readlink -f "$root_source" 2>/dev/null || echo "$root_source")
  [[ -b "$root_real" ]] || return 1

  parent_kname=$(lsblk -dno PKNAME "$root_real" 2>/dev/null | head -1 || true)
  if [[ -n "$parent_kname" ]]; then
    echo "/dev/${parent_kname}"
    return 0
  fi

  if [[ "$(lsblk -dnpo TYPE "$root_real" 2>/dev/null || true)" == "disk" ]]; then
    echo "$root_real"
    return 0
  fi

  return 1
}

# Находит новый дочерний раздел диска, отсутствовавший в списке имён до операции.
#
# @param $1  путь к диску (родитель)
# @param $2  многострочный список имён разделов до изменения (для сравнения)
# @stdout путь к новому разделу
# @return 0 при успехе, 1 если новый раздел не обнаружен
detect_new_partition() {
  local disk="$1"
  local before_list="$2"
  local part=""

  while IFS= read -r part; do
    [[ -z "$part" ]] && continue
    [[ "$part" == "$disk" ]] && continue
    if ! grep -qxF "$part" <<< "$before_list"; then
      echo "$part"
      return 0
    fi
  done < <(lsblk -rpno NAME "$disk" 2>/dev/null || true)

  return 1
}

# Возвращает координаты последнего свободного сегмента на диске (parted unit MiB).
#
# @param $1  путь к диску
# @stdout три числа: start end size (MiB)
# @return 0 при успехе, 1 если свободного места нет или парсинг не удался
get_last_free_segment_mib() {
  local disk="$1"
  local free_line
  local start end size

  free_line=$(LC_ALL=C parted -s "$disk" unit MiB print free 2>/dev/null | grep "Free Space" | tail -1 || true)
  [[ -n "$free_line" ]] || return 1

  start=$(echo "$free_line" | awk '{ gsub(/MiB/,"",$1); print int($1)+0 }')
  end=$(echo "$free_line" | awk '{ gsub(/MiB/,"",$2); print int($2)+0 }')
  size=$(echo "$free_line" | awk '{ gsub(/MiB/,"",$3); print int($3)+0 }')

  [[ -n "$start" && -n "$end" && -n "$size" ]] || return 1
  echo "${start} ${end} ${size}"
}

# Нормализует числовую переменную профиля по имени: при некорректном значении подставляет fallback.
#
# @param $1  имя переменной (indirect expansion)
# @param $2  значение по умолчанию при исправлении
# @globals имя из $1 — может быть перезаписано через printf -v
# @return 0
validate_numeric_profile_var() {
  local var_name="$1"
  local fallback="$2"
  local value="${!var_name:-}"

  if ! is_non_negative_int "${value}"; then
    log_warn "${var_name}=${value} некорректен, используется ${fallback}."
    printf -v "${var_name}" '%s' "${fallback}"
  fi
}

# Вызывает restorecon для пути, если утилита доступна (SELinux).
#
# @param $1  путь к дереву каталогов
# @return 0
restore_selinux_context_if_available() {
  local path="$1"
  if has_cmd restorecon; then
    restorecon -Rv "$path"
  fi
}

# Расширяет ФС на корне после увеличения блочного устройства (xfs_growfs / resize2fs).
#
# @return 0 при успехе или предупреждении для неподдержанного типа; 1 для неподдержанной ФС
grow_root_filesystem() {
  local fs_type
  fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null || true)
  case "$fs_type" in
    xfs) xfs_growfs / ;;
    ext4|ext3|ext2) resize2fs "$(findmnt -n -o SOURCE /)" ;;
    *)
      log_warn "ФС корня (${fs_type:-unknown}) не поддержана авто-расширением. Проверьте вручную."
      return 1
      ;;
  esac
}

# Заполняет MAIN_DISK: явный MAIN_DISK_DEVICE, иначе диск корня, иначе первый disk из lsblk.
#
# @globals MAIN_DISK_DEVICE MAIN_DISK
# @return 0
resolve_main_disk() {
  MAIN_DISK="${MAIN_DISK_DEVICE:-}"
  if [[ -z "$MAIN_DISK" ]]; then
    MAIN_DISK=$(detect_root_base_disk || true)
  fi
  if [[ -z "$MAIN_DISK" ]]; then
    MAIN_DISK=$(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}' | head -1 || true)
  fi
}

# Вычисляет условный «размер диска в GiB» и группу профиля DISK_SIZE_GROUP (округление).
#
# @globals MAIN_DISK DISK_SIZE_G DISK_SIZE_GROUP
# @return 0
resolve_disk_size_group() {
  DISK_SIZE_G=""
  if [[ -n "${MAIN_DISK:-}" ]]; then
    local size_bytes
    size_bytes=$(lsblk -dnbo SIZE "${MAIN_DISK}" 2>/dev/null || true)
    if [[ -n "$size_bytes" ]]; then
      DISK_SIZE_G=$((size_bytes / 1024 / 1024 / 1024))
    fi
  fi

  if [[ -n "${DISK_SIZE_G}" ]] && [[ "${DISK_SIZE_G}" -ge 20 ]] 2>/dev/null; then
    DISK_SIZE_GROUP=$(( (DISK_SIZE_G / 10) * 10 ))
  else
    DISK_SIZE_GROUP=30
  fi
}

_INFRA_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${_INFRA_REPO_ROOT}/config/disk-profiles.sh"
unset _INFRA_REPO_ROOT

# Загружает параметры дисков: матрица по DISK_SIZE_G, затем локальный DISK_VARS_FILE или shallow-клон репозитория.
#
# @globals DISK_VARS_FILE DISK_PROFILE_FETCH_FROM_REPO DISK_VARS_REPO_PATH REF_VALUE REPO_URL DISK_PROFILE_USE_MATRIX
# @return 0
load_disk_profile() {
  section "Профиль дисков"
  apply_disk_profile_matrix
  log_info "Основной диск: ${MAIN_DISK:-?}, размер ~${DISK_SIZE_G:-?}G, профиль ${DISK_SIZE_GROUP}G"

  if [[ -f "${DISK_VARS_FILE}" ]]; then
    log_info "Найден локальный файл параметров: ${DISK_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${DISK_VARS_FILE}"
    return 0
  fi

  if [[ "${DISK_PROFILE_FETCH_FROM_REPO}" != "1" ]]; then
    log_warn "Локальный файл ${DISK_VARS_FILE} не найден. Загрузка из репозитория отключена (DISK_PROFILE_FETCH_FROM_REPO=0), используются defaults."
    return 0
  fi

  log_warn "Локальный файл ${DISK_VARS_FILE} не найден, пробуем загрузить из репозитория (DISK_PROFILE_FETCH_FROM_REPO=1)."
  has_cmd git || dnf_install git

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  if git_repo clone -b "${REF_VALUE}" --depth 1 "${REPO_URL}" "${tmp_dir}"; then
    if [[ -f "${tmp_dir}/${DISK_VARS_REPO_PATH}" ]]; then
      install -d -m 0755 "$(dirname "${DISK_VARS_FILE}")"
      cp "${tmp_dir}/${DISK_VARS_REPO_PATH}" "${DISK_VARS_FILE}"
      chmod 0644 "${DISK_VARS_FILE}"
      # shellcheck disable=SC1090
      source "${DISK_VARS_FILE}"
      log_info "Параметры дисков сохранены в ${DISK_VARS_FILE}"
    else
      log_warn "Файл ${DISK_VARS_REPO_PATH} не найден в репозитории, используются defaults."
    fi
  else
    log_warn "Не удалось клонировать репозиторий для профиля дисков, используются defaults."
  fi
  rm -rf "${tmp_dir}"
}

# Задаёт значения по умолчанию для ROOT_TARGET_G, VAR_*, SWAP, MINIO и валидирует числа.
#
# @globals ROOT_TARGET_G VAR_MIN_FREE_MIB VAR_SIZE_G SWAP_SIZE_G MINIO_SIZE_G VAR_ALLOW_ROOT_DISK
# @return 0
apply_disk_defaults() {
  ROOT_TARGET_G="${ROOT_TARGET_G:-30}"
  VAR_MIN_FREE_MIB="${VAR_MIN_FREE_MIB:-1024}"
  VAR_SIZE_G="${VAR_SIZE_G:-15}"
  SWAP_SIZE_G="${SWAP_SIZE_G:-2}"
  MINIO_SIZE_G="${MINIO_SIZE_G:-0}"

  validate_numeric_profile_var ROOT_TARGET_G 30
  validate_numeric_profile_var VAR_MIN_FREE_MIB 1024
  validate_numeric_profile_var VAR_SIZE_G 15
  validate_numeric_profile_var SWAP_SIZE_G 2
  validate_numeric_profile_var MINIO_SIZE_G 0

  VAR_ALLOW_ROOT_DISK="${VAR_ALLOW_ROOT_DISK:-1}"
}

# Перед разметкой на диске с корнем при VAR_ALLOW_ROOT_DISK=1 — предупреждение и один раз Enter.
#
# @param $1  краткий контекст (диск, LVM и т.п.)
# @globals VAR_ALLOW_ROOT_DISK VAR_ALLOW_ROOT_DISK_SKIP_PROMPT _INFRA_ALLOW_ROOT_DISK_ACK
# @return 0
confirm_allow_root_disk_once() {
  local ctx="${1:-}"
  [[ "${VAR_ALLOW_ROOT_DISK:-1}" == "1" ]] || return 0
  [[ "${_INFRA_ALLOW_ROOT_DISK_ACK:-0}" == "1" ]] && return 0

  if [[ "${VAR_ALLOW_ROOT_DISK_SKIP_PROMPT:-0}" == "1" ]]; then
    log_warn "VAR_ALLOW_ROOT_DISK_SKIP_PROMPT=1: подтверждение разметки на диске с корнем пропущено.${ctx:+ ${ctx}}"
    _INFRA_ALLOW_ROOT_DISK_ACK=1
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log_warn "stdin не TTY: подтверждение разметки на диске с корнем пропущено.${ctx:+ ${ctx}}"
    _INFRA_ALLOW_ROOT_DISK_ACK=1
    return 0
  fi

  log_warn "ВНИМАНИЕ: будет разметка на диске с корневой файловой системой (VAR_ALLOW_ROOT_DISK=1). Риск потери данных при ошибке.${ctx:+ ${ctx}}"
  log_warn "Нажмите Enter для продолжения или Ctrl+C для отмены."
  read -r _ || true
  _INFRA_ALLOW_ROOT_DISK_ACK=1
}

# Создаёт файл подкачки /swapfile и подключает swap, если текущего swap мало.
#
# @globals SWAP_SIZE_G
# @return 0
ensure_swap() {
  section "Swap"
  log_info "Проверка swap (целевой размер ${SWAP_SIZE_G}G)"

  local current_swap_kib current_swap_g need_swap_g
  current_swap_kib=$(awk 'NR>1 {total+=$3} END {print int(total)}' /proc/swaps 2>/dev/null || true)
  current_swap_g=$(( ${current_swap_kib:-0} / 1024 / 1024 ))

  if [[ "${SWAP_SIZE_G}" -le 0 ]]; then
    log_info "SWAP_SIZE_G=${SWAP_SIZE_G}, создание swap не требуется."
    return 0
  fi
  if [[ "${current_swap_g:-0}" -ge "${SWAP_SIZE_G}" ]]; then
    log_info "Swap уже настроен: ${current_swap_g}G."
    return 0
  fi
  if [[ -f /swapfile ]]; then
    log_warn "/swapfile уже существует, автоматическое создание пропущено."
    return 0
  fi

  need_swap_g=$(( SWAP_SIZE_G - current_swap_g ))
  [[ "$need_swap_g" -ge 1 ]] || need_swap_g=1

  log_info "Создаем /swapfile на ${need_swap_g}G"
  if ! fallocate -l "${need_swap_g}G" /swapfile 2>/dev/null; then
    dd if=/dev/zero of=/swapfile bs=1G count="${need_swap_g}" status=none
  fi
  chmod 0600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  append_fstab_once "/swapfile  swap  swap  defaults  0  0"
}

# Расширяет root LV и ФС до ROOT_TARGET_G при наличии свободного места в VG/partition.
#
# @globals ROOT_TARGET_G ROOT_LV ROOT_SIZE_G ROOT_VG
# @return 0 при пропуске или успехе; предупреждения при сбоях growpart/lvm
expand_root_lv_if_needed() {
  section "Расширение root LV"

  if ! has_cmd lvs || ! has_cmd pvs; then
    log_warn "LVM утилиты отсутствуют, пропускаем расширение root."
    return 0
  fi

  ROOT_LV=$(lvs --noheadings -o lv_path 2>/dev/null | awk '/root/ {gsub(/ /,"",$0); print; exit}' || true)
  ROOT_SIZE_G=$(lvs --noheadings -o lv_size --units g --nosuffix "${ROOT_LV:-}" 2>/dev/null | tr -d ' ' | cut -d. -f1 || true)
  ROOT_VG=$(lvs --noheadings -o vg_name "${ROOT_LV:-}" 2>/dev/null | tr -d ' ' || true)

  if [[ -z "${ROOT_LV:-}" ]] || [[ "${ROOT_SIZE_G:-0}" -ge "${ROOT_TARGET_G}" ]]; then
    log_info "Расширение root не требуется (текущий размер: ${ROOT_SIZE_G:-?}G)."
    return 0
  fi

  local lvm_part lvm_disk lvm_part_num
  if [[ -n "${ROOT_VG:-}" ]]; then
    lvm_part=$(pvs --noheadings -o pv_name -S "vg_name=${ROOT_VG}" 2>/dev/null | tr -d ' ' | head -1 || true)
  else
    lvm_part=$(pvs --noheadings -o pv_name 2>/dev/null | tr -d ' ' | head -1 || true)
  fi
  lvm_disk=$(disk_base_name "$lvm_part")
  lvm_part_num=$(echo "$lvm_part" | grep -o '[0-9]\+$' || true)

  if [[ -z "$lvm_part" || -z "$lvm_part_num" ]]; then
    log_warn "Не удалось определить PV раздел для growpart, пропускаем расширение root."
    return 0
  fi

  has_cmd growpart || dnf_install cloud-utils-growpart
  growpart "$lvm_disk" "$lvm_part_num" || log_warn "growpart не изменил раздел (возможно, уже расширен)."
  pvresize "$lvm_part"
  lvextend -L "${ROOT_TARGET_G}G" "$ROOT_LV"
  grow_root_filesystem || true
  log_info "root LV приведен к ${ROOT_TARGET_G}G (если хватило места в VG)."
}

# Подбирает диск и диапазон свободного места для выделения /var разделами (не LVM).
#
# @globals VAR_ALLOW_ROOT_DISK VAR_DISK_DEVICE ROOT_VG VAR_DISK VAR_FREE_START VAR_FREE_END VAR_MIN_FREE_MIB
# @return 0 если диск найден, 1 если подходящего нет
select_target_disk_for_var() {
  VAR_DISK=""
  VAR_FREE_START=""
  VAR_FREE_END=""

  local allow_root_disk var_disk_device root_base_disk disk free_triplet free_start free_end free_size
  allow_root_disk="${VAR_ALLOW_ROOT_DISK:-1}"
  var_disk_device="${VAR_DISK_DEVICE:-}"
  root_base_disk=""

  if [[ -n "${ROOT_VG:-}" ]]; then
    local root_pv
    root_pv=$(pvs --noheadings -o pv_name -S "vg_name=${ROOT_VG}" 2>/dev/null | tr -d ' ' | head -1 || true)
    root_base_disk=$(disk_base_name "$root_pv")
  fi
  [[ -n "$root_base_disk" ]] || root_base_disk=$(detect_root_base_disk || true)
  [[ -n "$root_base_disk" ]] && log_info "Определен root-диск: ${root_base_disk}"

  # Внутренняя: проверяет кандидата в диски и достаточность свободного хвоста (MiB).
  #
  # @param $1  путь к диску /dev/…
  # @return 0 если VAR_DISK выбран
  pick_disk() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return 1
    [[ "$(lsblk -dnpo TYPE "$candidate" 2>/dev/null || true)" == "disk" ]] || return 1
    if [[ "$allow_root_disk" != "1" ]] && [[ -n "$root_base_disk" ]] && [[ "$candidate" == "$root_base_disk" ]]; then
      log_warn "Пропускаем root-диск ${candidate} (VAR_ALLOW_ROOT_DISK=0)."
      return 1
    fi
    free_triplet=$(get_last_free_segment_mib "$candidate" || true)
    [[ -n "$free_triplet" ]] || return 1
    read -r free_start free_end free_size <<< "$free_triplet"
    if [[ "$free_size" -ge "$VAR_MIN_FREE_MIB" ]]; then
      if [[ "$allow_root_disk" == "1" ]] && [[ -n "$root_base_disk" ]] && [[ "$candidate" == "$root_base_disk" ]]; then
        confirm_allow_root_disk_once "Диск ${candidate}: новые разделы в свободном хвосте."
      fi
      VAR_DISK="$candidate"
      VAR_FREE_START="$free_start"
      VAR_FREE_END="$free_end"
      return 0
    fi
    return 1
  }

  if [[ -n "$var_disk_device" ]]; then
    log_info "Явно задан диск для /var и /minio: ${var_disk_device}"
    pick_disk "$var_disk_device" || return 1
    return 0
  fi

  while IFS= read -r disk; do
    pick_disk "$disk" && return 0
  done < <(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}')

  return 1
}

# Создаёт раздел xfs в конце свободного сегмента; возвращает путь к новому разделу.
#
# @param $1  диск
# @param $2  метка раздела (GPT) или primary (MBR)
# @param $3  требуемый размер в MiB (0 — использовать весь доступный хвост)
# @stdout путь к новому разделу
# @return 0 при успехе, 1 при ошибке parted/таблицы
create_partition_from_free_tail() {
  local disk="$1"
  local part_label="$2"
  local need_mib="$3"
  local part_table start_mib end_mib size_mib before_parts new_part free_triplet

  part_table=$(LC_ALL=C parted -s "$disk" print 2>/dev/null | awk '/Partition Table:/ {print $3}')
  free_triplet=$(get_last_free_segment_mib "$disk" || true)
  [[ -n "$free_triplet" ]] || return 1
  read -r start_mib end_mib size_mib <<< "$free_triplet"

  if [[ "$need_mib" -gt 0 ]]; then
    [[ "$size_mib" -ge "$need_mib" ]] || return 1
    local requested_end
    requested_end=$(( start_mib + need_mib ))
    if [[ "$requested_end" -lt "$end_mib" ]]; then
      end_mib="$requested_end"
    fi
  fi

  before_parts="$(lsblk -rpno NAME "$disk" 2>/dev/null || true)"
  case "$part_table" in
    gpt)
      parted -s "$disk" unit MiB mkpart "$part_label" xfs "$start_mib" "$end_mib"
      ;;
    msdos)
      parted -s "$disk" unit MiB mkpart primary xfs "$start_mib" "$end_mib"
      ;;
    *)
      log_warn "Неизвестная таблица разделов на ${disk}: ${part_table:-unknown}"
      return 1
      ;;
  esac

  partprobe "$disk"
  udevadm settle --timeout=10 2>/dev/null || sleep 3

  new_part=$(detect_new_partition "$disk" "$before_parts" || true)
  if [[ -z "${new_part}" ]]; then
    new_part=$(lsblk -rpno NAME "$disk" 2>/dev/null | grep -v "^${disk}$" | tail -1 | tr -d ' ' || true)
  fi
  [[ -n "${new_part}" ]] || return 1
  echo "$new_part"
}

# Форматирует раздел в xfs, копирует /var через rsync/cp, монтирует /var, правит fstab.
#
# @param $1  путь к блочному устройству раздела
# @return 0 при успехе, 1 при ошибке mkfs/mount/uuid
migrate_var_to_partition() {
  local part="$1"
  local var_uuid tmp_mnt

  mkfs.xfs -f "$part"
  var_uuid=$(blkid -s UUID -o value "$part" || true)
  [[ -n "$var_uuid" ]] || return 1

  tmp_mnt=$(mktemp -d /mnt/bootstrap-var.XXXXXX)
  mount "$part" "$tmp_mnt"
  if has_cmd rsync; then
    rsync -aHAX --numeric-ids /var/ "$tmp_mnt/"
  else
    cp -ax /var/. "$tmp_mnt/"
  fi
  umount "$tmp_mnt"
  rmdir "$tmp_mnt"

  mount "$part" /var
  restore_selinux_context_if_available /var
  append_fstab_once "UUID=${var_uuid}  /var  xfs  defaults  0 2"
  log_info "/var перенесен на ${part} (UUID=${var_uuid})"
}

# Выделяет раздел на конкретном диске под /minio (отдельные разделы, не LVM).
#
# @param $1  диск, на котором после /var остаётся свободное место
# @globals MINIO_SIZE_G
# @return 0
setup_minio_partition() {
  local disk="$1"
  local minio_need_mib minio_part minio_uuid

  [[ "${MINIO_SIZE_G}" -gt 0 ]] || return 0
  if [[ "$(findmnt -n -o TARGET /minio 2>/dev/null || true)" == "/minio" ]]; then
    log_info "/minio уже смонтирован, пропускаем."
    return 0
  fi

  minio_need_mib=$(( MINIO_SIZE_G * 1024 ))
  minio_part=$(create_partition_from_free_tail "$disk" "minio" "$minio_need_mib" || true)
  if [[ -z "${minio_part}" ]]; then
    log_warn "Не удалось выделить раздел для /minio (${MINIO_SIZE_G}G), пропускаем."
    return 0
  fi

  mkfs.xfs -f "$minio_part"
  minio_uuid=$(blkid -s UUID -o value "$minio_part" || true)
  if [[ -z "${minio_uuid}" ]]; then
    log_warn "Не удалось получить UUID для /minio, пропускаем."
    return 0
  fi

  install -d -m 0755 /minio
  mount "$minio_part" /minio
  restore_selinux_context_if_available /minio
  append_fstab_once "UUID=${minio_uuid}  /minio  xfs  defaults  0 2"
  log_info "/minio создан на ${minio_part} (UUID=${minio_uuid}, ${MINIO_SIZE_G}G)"
}

# Заполняет ROOT_LV и ROOT_VG из lvs, если корень на LVM.
#
# @globals ROOT_LV ROOT_VG
# @return 0 если метаданные уже были или успешно прочитаны; 1 если LVM недоступен
ensure_root_lvm_metadata() {
  if [[ -n "${ROOT_LV:-}" ]] && [[ -n "${ROOT_VG:-}" ]]; then
    return 0
  fi
  has_cmd lvs || return 1
  ROOT_LV=$(lvs --noheadings -o lv_path 2>/dev/null | awk '/root/ {gsub(/ /,"",$0); print; exit}' || true)
  ROOT_VG=$(lvs --noheadings -o vg_name "${ROOT_LV:-}" 2>/dev/null | tr -d ' ' || true)
  [[ -n "${ROOT_LV:-}" ]] && [[ -n "${ROOT_VG:-}" ]]
}

# Возвращает целое число гигабайт свободного места в VG.
#
# @param $1  имя volume group
# @stdout свободные GiB (усечённо до целого)
vg_free_gib() {
  local vg="$1"
  local raw
  raw=$(vgs --noheadings -o vg_free --units g --nosuffix "${vg}" 2>/dev/null | tr -d ' ' || true)
  echo "${raw%%.*}"
}

# Возвращает путь к LV по имени в VG (/dev/…), если LV существует.
#
# @param $1  имя VG
# @param $2  имя LV
# @stdout путь lv_path или пусто
lv_path_by_name() {
  local vg="$1"
  local name="$2"
  if ! lvs "${vg}/${name}" &>/dev/null; then
    return 0
  fi
  lvs --noheadings -o lv_path "${vg}/${name}" 2>/dev/null | tr -d ' '
}

# Создаёт LV minio в ROOT_VG, xfs, монтирует /minio.
#
# @param $1  размер в GiB (по умолчанию MINIO_SIZE_G)
# @globals ROOT_VG MINIO_SIZE_G
# @return 0
setup_minio_lvm() {
  local minio_g="${1:-${MINIO_SIZE_G}}"
  local minio_lv minio_uuid

  [[ "${minio_g}" -gt 0 ]] || return 0
  if [[ "$(findmnt -n -o TARGET /minio 2>/dev/null || true)" == "/minio" ]]; then
    log_info "/minio уже смонтирован, пропускаем."
    return 0
  fi

  [[ -n "${ROOT_VG:-}" ]] || return 1
  has_cmd lvcreate || dnf_install lvm2

  minio_lv=$(lv_path_by_name "${ROOT_VG}" "minio")
  if [[ -z "${minio_lv}" ]]; then
    lvcreate -y -L "${minio_g}G" -n minio "${ROOT_VG}"
    minio_lv=$(lv_path_by_name "${ROOT_VG}" "minio")
  fi
  [[ -n "${minio_lv}" ]] || return 1

  mkfs.xfs -f "${minio_lv}"
  minio_uuid=$(blkid -s UUID -o value "${minio_lv}" || true)
  [[ -n "${minio_uuid}" ]] || return 1

  install -d -m 0755 /minio
  mount "${minio_lv}" /minio
  restore_selinux_context_if_available /minio
  append_fstab_once "UUID=${minio_uuid}  /minio  xfs  defaults  0 2"
  log_info "/minio создан на LV ${minio_lv} (UUID=${minio_uuid}, ${minio_g}G)"
}

# Вариант с LVM в том же VG, что и root: LV var + опционально minio при VAR_ALLOW_ROOT_DISK=1.
#
# @globals VAR_ALLOW_ROOT_DISK ROOT_VG VAR_SIZE_G MINIO_SIZE_G MIN_MINIO_G
# @return 0 при успехе, 1 при недостатке места или ошибках lvcreate
prepare_var_and_minio_lvm() {
  local vg_free vg_need var_lv rem minio_g min_minio

  if [[ "${VAR_ALLOW_ROOT_DISK:-1}" != "1" ]]; then
    log_warn "LVM: выделение /var и /minio в VG отключено (VAR_ALLOW_ROOT_DISK=0)."
    return 1
  fi

  if ! ensure_root_lvm_metadata; then
    log_warn "LVM: корень не на LVM или метаданные VG недоступны."
    return 1
  fi

  has_cmd lvcreate || dnf_install lvm2

  vg_free=$(vg_free_gib "${ROOT_VG}")
  [[ -n "${vg_free}" ]] || vg_free=0
  if [[ "${vg_free}" -lt "${VAR_SIZE_G}" ]] 2>/dev/null; then
    log_warn "LVM: в VG ${ROOT_VG} недостаточно места под /var (нужно ${VAR_SIZE_G}G, свободно ${vg_free}G)."
    return 1
  fi

  minio_g="${MINIO_SIZE_G}"
  min_minio="${MIN_MINIO_G:-15}"
  if [[ "${minio_g}" -gt 0 ]]; then
    vg_need=$(( VAR_SIZE_G + minio_g ))
    if [[ "${vg_free}" -lt "${vg_need}" ]] 2>/dev/null; then
      rem=$(( vg_free - VAR_SIZE_G ))
      if [[ "${rem}" -ge "${min_minio}" ]]; then
        log_warn "LVM: MinIO уменьшен с ${minio_g}G до ${rem}G (остаток VG после /var)."
        minio_g="${rem}"
      elif [[ "${rem}" -gt 0 ]]; then
        log_warn "LVM: после /var остаётся ${rem}G — меньше MIN_MINIO_G (${min_minio}), MinIO не создаём."
        minio_g=0
      else
        log_warn "LVM: места под MinIO нет, MinIO пропускаем."
        minio_g=0
      fi
    fi
  fi

  vg_need="${VAR_SIZE_G}"
  [[ "${minio_g}" -gt 0 ]] && vg_need=$(( vg_need + minio_g ))
  if [[ "${vg_free}" -lt "${vg_need}" ]] 2>/dev/null; then
    log_warn "LVM: в VG ${ROOT_VG} недостаточно места (нужно ~${vg_need}G, свободно ${vg_free}G)."
    return 1
  fi

  log_info "LVM: VG=${ROOT_VG}, свободно ~${vg_free}G, план: /var ${VAR_SIZE_G}G, /minio ${minio_g}G"

  confirm_allow_root_disk_once "LVM: VG ${ROOT_VG}, LV var и при необходимости minio на диске с корнем."

  var_lv=$(lv_path_by_name "${ROOT_VG}" "var")
  if [[ -z "${var_lv}" ]]; then
    lvcreate -y -L "${VAR_SIZE_G}G" -n var "${ROOT_VG}"
    var_lv=$(lv_path_by_name "${ROOT_VG}" "var")
  fi
  [[ -n "${var_lv}" ]] || return 1

  if ! migrate_var_to_partition "${var_lv}"; then
    log_warn "LVM: перенос /var на ${var_lv} не удалён."
    return 1
  fi

  setup_minio_lvm "${minio_g}"
  return 0
}

# Сначала пытается разметить /var и /minio отдельными разделами; иначе — вариант LVM.
#
# @return 0 (в т.ч. при уже вынесенном /var или при отказе с предупреждением)
prepare_var_and_minio() {
  section "Разметка /var и /minio"

  if [[ "$(findmnt -n -o TARGET /var 2>/dev/null || true)" == "/var" ]]; then
    log_info "/var уже на отдельном разделе ($(findmnt -n -o SOURCE /var 2>/dev/null || true))."
    return 0
  fi

  ensure_root_lvm_metadata || true

  if select_target_disk_for_var; then
    log_info "Выбран диск (разделы): ${VAR_DISK}, свободный диапазон: ${VAR_FREE_START}-${VAR_FREE_END} MiB"
    local var_need_mib var_part
    var_need_mib=$(( VAR_SIZE_G * 1024 ))
    var_part=$(create_partition_from_free_tail "${VAR_DISK}" "var" "${var_need_mib}" || true)
    if [[ -n "${var_part}" ]] && migrate_var_to_partition "${var_part}"; then
      setup_minio_partition "${VAR_DISK}"
      return 0
    fi
    log_warn "Разделы для /var не созданы или перенос не удался, пробуем LVM в VG ${ROOT_VG:-}."
  else
    log_warn "Диск с неразмеченным хвостом >= ${VAR_MIN_FREE_MIB} MiB не найден, пробуем LVM в VG ${ROOT_VG:-}."
  fi

  if prepare_var_and_minio_lvm; then
    return 0
  fi

  log_warn "Разметка /var и /minio не выполнена (см. сообщения выше)."
  return 0
}

# Точка входа шага 40: профиль дисков, swap, root LV, /var и /minio.
#
# @return 0
step_disk_storage() {
  resolve_main_disk
  resolve_disk_size_group
  load_disk_profile
  apply_disk_defaults

  ensure_swap
  expand_root_lv_if_needed
  prepare_var_and_minio
}
