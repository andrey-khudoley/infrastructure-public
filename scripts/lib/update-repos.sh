# shellcheck shell=bash
#
# Общие функции синхронизации репозиториев для update/run-git-* сценариев.
# Требует, чтобы вызывающий скрипт заранее подключил:
#   - scripts/lib/common.sh
#   - scripts/lib/load-env.sh
#   - scripts/lib/require-bootstrap-config.sh (если нужен require_bootstrap_config_files)
#   - scripts/50-sync-repository.sh (для sync_repository)
#
# И чтобы были доступны ROOT, PUBLIC_REPO_URL, PUBLIC_REF_VALUE, PULL_DIR, REF_VALUE.

# Синхронизирует текущий клон infrastructure-public с PUBLIC_REPO_URL/PUBLIC_REF_VALUE.
#
# @globals ROOT PUBLIC_REPO_URL PUBLIC_REF_VALUE
# @return 0 при успехе git-операций
sync_public_repository() {
  section "Публичный репозиторий"
  [[ -n "${PUBLIC_REPO_URL:-}" ]] || fail "Задайте PUBLIC_REPO_URL в config/repos.env или окружении."

  log_info "Обновление ${ROOT} <- ${PUBLIC_REPO_URL} (${PUBLIC_REF_VALUE})"
  if [[ ! -d "${ROOT}/.git" ]]; then
    fail "Нет ${ROOT}/.git — sync public работает только для git-клона (не архива)."
  fi

  (
    cd "${ROOT}"
    if git remote get-url origin &>/dev/null; then
      prev=$(git remote get-url origin)
      if [[ "${prev}" != "${PUBLIC_REPO_URL}" ]]; then
        log_warn "origin был ${prev}, выставляем ${PUBLIC_REPO_URL} (как в PUBLIC_REPO_URL)."
      fi
      git_repo remote set-url origin "${PUBLIC_REPO_URL}"
    else
      git_repo remote add origin "${PUBLIC_REPO_URL}"
    fi
    git_repo fetch origin "${PUBLIC_REF_VALUE}"
    git_repo checkout "${PUBLIC_REF_VALUE}"
  )
}

# Печатает подсказку о следующем ручном шаге после update.
#
# @globals PUBLIC_REF_VALUE PULL_DIR REF_VALUE
# @return 0
print_next_steps_hint() {
  section "Готово"
  log_info "Публичный репозиторий: ${PUBLIC_REF_VALUE}. Приватный: ${PULL_DIR} (${REF_VALUE})."
  log_info "Чтобы применить изменения на узле, выполните вручную в корне клона приватного репо:"
  echo "    cd ${PULL_DIR}"
  echo "    sudo make runtime"
  echo
  log_info "Для повторного прогона bootstrap-фаз используйте make stage1 / make stage2 в том же каталоге."
}
