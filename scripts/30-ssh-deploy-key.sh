# shellcheck shell=bash
# Deploy key для git@ / ssh:// REPO_URL.

repo_url_is_ssh() {
  [[ "${REPO_URL}" == git@* ]] || [[ "${REPO_URL}" == ssh://* ]]
}

ensure_infra_deploy_key() {
  repo_url_is_ssh || return 0

  section "SSH-ключ для репозитория (deploy key)"
  if ! has_cmd ssh-keygen; then
    dnf_install openssh-clients
  fi

  install -d -m 0700 "$(dirname "${INFRA_SSH_KEY}")"

  if [[ -f "${INFRA_SSH_KEY}" ]]; then
    log_info "Ключ уже существует (${INFRA_SSH_KEY}), новый не создаём."
  else
    log_info "Создаём ключ: ${INFRA_SSH_KEY} (${INFRA_SSH_KEY_COMMENT})"
    ssh-keygen -q -t ed25519 -N "" -C "${INFRA_SSH_KEY_COMMENT}" -f "${INFRA_SSH_KEY}"
    chmod 600 "${INFRA_SSH_KEY}" 2>/dev/null || true
    echo
    log_info "Публичный ключ — добавьте его в Deploy keys (read-only) репозитория:"
    echo
    cat "${INFRA_SSH_KEY}.pub"
    echo
    if [[ "${INFRA_SSH_SKIP_PROMPT}" != "1" ]]; then
      read -r -p "После добавления ключа нажмите Enter для продолжения… " _
    fi
  fi

  export GIT_SSH_COMMAND="ssh -i \"${INFRA_SSH_KEY}\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
}

step_ssh_deploy_key() {
  ensure_infra_deploy_key
}
