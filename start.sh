#!/usr/bin/env bash
#
# Bootstrap-хоста под инфраструктурный Ansible (публичный репозиторий).
#
# Назначение:
#   Один сценарий верхнего уровня: подготовка ОС (dnf, диски, SSH-ключ для git),
#   клон приватного репозитория с плейбуками в PULL_DIR и вход в прикладную
#   логику через две цели Make внутри клона — «make install-deps» (коллекции
#   Ansible Galaxy) и «make bootstrap» (фаза stage1 единого playbooks/site.yml).
#
# Порядок шагов (не менять без обновления README и зависимостей между шагами):
#   10  root/dnf/утилиты
#   20  пакеты (+ ansible-core и make, если не SKIP_ANSIBLE)
#   30  github.com HTTPS → git@… при необходимости; deploy key для SSH-URL приватного репо
#   40  диски, swap, при необходимости /var и /minio
#   50  git clone/fetch в PULL_DIR
#   70  make install-deps + make bootstrap в PULL_DIR (контракт с приватным репо)
#   90  distro-sync и проверка sshd / NetworkManager
#
# Конфигурация:
#   Переменные по умолчанию — scripts/lib/env.sh; переопределение — через окружение
#   перед запуском: ENV=stage REF=main REPO_URL=... bash start.sh
#
# Ограничение:
#   Скрипт должен запускаться из каталога клона этого репозитория (нужны scripts/).
#   Запуск через «curl … | bash» не поддерживается — не определяется ROOT.
#
# Подробности: README.md

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/env.sh
source "${ROOT}/scripts/lib/env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
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
# shellcheck source=scripts/70-ansible-pull-stage1.sh
source "${ROOT}/scripts/70-ansible-pull-stage1.sh"
# shellcheck source=scripts/90-finalize.sh
source "${ROOT}/scripts/90-finalize.sh"

step_require_runtime
step_install_packages
step_ssh_deploy_key
step_disk_storage
step_sync_repository
step_ansible_pull_stage1
step_finalize
