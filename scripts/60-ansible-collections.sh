# shellcheck shell=bash
# Коллекции Galaxy: делегирование в приватный репозиторий (run.sh → make install-deps).

step_ansible_collections() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    return 0
  fi

  section "Ansible Galaxy"
  local run="${PULL_DIR}/run.sh"
  if [[ ! -f "${run}" ]]; then
    fail "Не найден ${run}. В корне приватного репозитория должен быть run.sh (make install-deps)."
  fi
  chmod +x "${run}" 2>/dev/null || true

  (
    cd "${PULL_DIR}"
    export GALAXY_DOWNLOAD_DIR="${GALAXY_DOWNLOAD_DIR}"
    export GALAXY_INSTALL_TIMEOUT="${GALAXY_INSTALL_TIMEOUT}"
    export GALAXY_INSTALL_RETRIES="${GALAXY_INSTALL_RETRIES}"
    export GALAXY_RETRY_SLEEP_SEC="${GALAXY_RETRY_SLEEP_SEC}"
    export COLLECTIONS_REQ="${COLLECTIONS_REQ:-${PULL_DIR}/collections/requirements.yml}"
    ./run.sh install-deps
  )
}
