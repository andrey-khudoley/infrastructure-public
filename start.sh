#!/usr/bin/env bash
#
# Bootstrap-хоста под инфраструктурный Ansible (публичный репозиторий).
#
# Назначение:
#   Один сценарий верхнего уровня для подготовки ОС: диски, swap, затем dnf-пакеты,
#   SSH-ключ для git, клон приватного репозитория с плейбуками в PULL_DIR и
#   установка зависимостей Ansible (make install-deps в корне клона). После
#   distro-sync и проверок выполняется make update-sysuser (имя/пароль админа);
#   запуск фазы stage1 (и далее stage2/runtime) — отдельный ручной шаг,
#   скрипт лишь печатает подсказку с командой после этого.
#
# Порядок шагов (не менять без обновления README и зависимостей между шагами):
#   10  root/dnf/утилиты
#   20  диски, swap, при необходимости /var и /minio — до тяжёлого dnf (шаг 30), чтобы
#       не упираться в OOM до появления swap
#   30  пакеты (+ make, если не SKIP_ANSIBLE; ansible-core ставится в .venv на
#       шаге 70 из приватного constraints.txt — единый контур версий)
#   40  github.com HTTPS → git@… при необходимости; deploy key для SSH-URL приватного репо
#   50  git clone/fetch в PULL_DIR
#   70  make install-deps в PULL_DIR (контракт с приватным репо)
#   90  distro-sync, проверка sshd / NetworkManager, make update-sysuser,
#       затем подсказка про make stage1
#
# Конфигурация:
#   После git clone: make init — копирует config/*.example в рабочие *.env и disk.env.
#   Затем при необходимости правка config/ и запуск (см. scripts/lib/load-env.sh).
#   Переопределение отдельных ключей — переменными окружения перед запуском:
#   ENV=stage REF=main REPO_URL=... bash start.sh
#
# Ограничение:
#   Скрипт должен запускаться из каталога клона этого репозитория (нужны scripts/).
#   Запуск через «curl … | bash» не поддерживается — не определяется ROOT.
#
# Подробности: README.md

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/load-env.sh
source "${ROOT}/scripts/lib/load-env.sh"
# shellcheck source=scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
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
