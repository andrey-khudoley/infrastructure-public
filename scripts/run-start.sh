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
# shellcheck source=scripts/10-require-runtime.sh
source "${ROOT}/scripts/10-require-runtime.sh"
# shellcheck source=scripts/20-disk-storage.sh
source "${ROOT}/scripts/20-disk-storage.sh"
# shellcheck source=scripts/30-install-packages.sh
source "${ROOT}/scripts/30-install-packages.sh"
# shellcheck source=scripts/40-ssh-deploy-key.sh
source "${ROOT}/scripts/40-ssh-deploy-key.sh"
# shellcheck source=scripts/50-sync-repository.sh
source "${ROOT}/scripts/50-sync-repository.sh"
# shellcheck source=scripts/70-install-deps.sh
source "${ROOT}/scripts/70-install-deps.sh"
# shellcheck source=scripts/90-finalize.sh
source "${ROOT}/scripts/90-finalize.sh"

step_require_runtime
step_disk_storage
step_install_packages
step_ssh_deploy_key
step_sync_repository
step_install_deps
step_finalize
