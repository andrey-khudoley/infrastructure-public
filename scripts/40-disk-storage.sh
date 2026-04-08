# shellcheck shell=bash
# Профиль дисков, swap, root LV, /var и /minio.

step_disk_storage() {
  resolve_main_disk
  resolve_disk_size_group
  load_disk_profile
  apply_disk_defaults

  ensure_swap
  expand_root_lv_if_needed
  prepare_var_and_minio
}
