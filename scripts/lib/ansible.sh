# shellcheck shell=bash
# Клон репозитория и ansible-pull stage1. Требует common.sh (git_repo, fail, section, log_*).

sync_repository() {
  section "Репозиторий"
  log_info "Синхронизация ${REPO_URL} (${REF_VALUE}) -> ${PULL_DIR}"
  install -d -m 0755 "$(dirname "${PULL_DIR}")"

  if [[ -d "${PULL_DIR}/.git" ]]; then
    (
      cd "${PULL_DIR}"
      if git remote get-url origin &>/dev/null; then
        prev=$(git remote get-url origin)
        if [[ "${prev}" != "${REPO_URL}" ]]; then
          log_warn "origin был ${prev}, выставляем ${REPO_URL} (как в REPO_URL)."
        fi
        git_repo remote set-url origin "${REPO_URL}"
      else
        git_repo remote add origin "${REPO_URL}"
      fi
      git_repo fetch origin "${REF_VALUE}"
      git_repo checkout "${REF_VALUE}"
    )
  else
    git_repo clone -b "${REF_VALUE}" "${REPO_URL}" "${PULL_DIR}"
  fi
}

prepare_ansible_pull_inventory() {
  local base="${PULL_DIR}/inventory.ini"
  local out="${PULL_DIR}/inventory.pull.ini"

  [[ -f "${base}" ]] || fail "Не найден ${base}. Нужен inventory.ini в репозитории (см. inventory.example.ini)."

  cp "${base}" "${out}"
}

run_stage1_ansible_pull() {
  section "Первый запуск stage1"
  prepare_ansible_pull_inventory
  cd "${PULL_DIR}"
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0= \
    env -u ANSIBLE_INVENTORY ANSIBLE_FORKS=1 \
    /usr/bin/ansible-pull \
    -U "${REPO_URL}" -C "${REF_VALUE}" \
    --directory "${PULL_DIR}" \
    -i "${PULL_DIR}/inventory.pull.ini" \
    bootstrap.yml --tags stage1 -e env="${ENV_VALUE}"
}
