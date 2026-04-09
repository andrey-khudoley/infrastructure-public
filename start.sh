#!/usr/bin/env bash
# Цепочка подготовки хоста: ОС и диски → репозиторий → run.sh install-deps → run.sh stage1-pull (make в клоне).
# См. README.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/env.sh
source "${ROOT}/scripts/lib/env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=scripts/lib/disk.sh
source "${ROOT}/scripts/lib/disk.sh"
# shellcheck source=scripts/lib/ansible.sh
source "${ROOT}/scripts/lib/ansible.sh"

# shellcheck source=scripts/10-require-runtime.sh
source "${ROOT}/scripts/10-require-runtime.sh"
# shellcheck source=scripts/20-install-packages.sh
source "${ROOT}/scripts/20-install-packages.sh"
# shellcheck source=scripts/30-ssh-deploy-key.sh
source "${ROOT}/scripts/30-ssh-deploy-key.sh"
# shellcheck source=scripts/40-disk-storage.sh
source "${ROOT}/scripts/40-disk-storage.sh"
# shellcheck source=scripts/50-sync-repository.sh
source "${ROOT}/scripts/50-sync-repository.sh"
# shellcheck source=scripts/60-ansible-collections.sh
source "${ROOT}/scripts/60-ansible-collections.sh"
# shellcheck source=scripts/70-ansible-pull-stage1.sh
source "${ROOT}/scripts/70-ansible-pull-stage1.sh"
# shellcheck source=scripts/90-finalize.sh
source "${ROOT}/scripts/90-finalize.sh"

step_require_runtime
step_install_packages
step_ssh_deploy_key
step_disk_storage
step_sync_repository
step_ansible_collections
step_ansible_pull_stage1
step_finalize
