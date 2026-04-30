#!/usr/bin/env bash

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# shellcheck source=scripts/lib/load-env.sh
source "${ROOT}/scripts/lib/load-env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
log_forwarded_make_args "$@"
# shellcheck source=scripts/lib/require-bootstrap-config.sh
source "${ROOT}/scripts/lib/require-bootstrap-config.sh"

require_bootstrap_config_files

# shellcheck source=scripts/40-ssh-deploy-key.sh
source "${ROOT}/scripts/40-ssh-deploy-key.sh"
# shellcheck source=scripts/50-sync-repository.sh
source "${ROOT}/scripts/50-sync-repository.sh"

prepare_ssh_for_infra_repos
sync_repository
log_info "Готово: синхронизирован только приватный репозиторий."
