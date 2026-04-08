# shellcheck shell=bash
# Параметры запуска (по умолчанию). Подключается из start.sh.

ENV_VALUE="${ENV:-ctl}"                                    # ctl|stage|prod
REPO_URL="${REPO_URL:-https://git.example.com/infra.git}"
REF_VALUE="${REF:-main}"
PULL_DIR="${PULL_DIR:-/var/lib/infra/src}"
SKIP_ANSIBLE="${SKIP_ANSIBLE:-0}"

GALAXY_INSTALL_TIMEOUT="${GALAXY_INSTALL_TIMEOUT:-300}"
GALAXY_DOWNLOAD_DIR="${GALAXY_DOWNLOAD_DIR:-/var/lib/infra/galaxy-download}"
GALAXY_INSTALL_RETRIES="${GALAXY_INSTALL_RETRIES:-5}"
GALAXY_RETRY_SLEEP_SEC="${GALAXY_RETRY_SLEEP_SEC:-10}"

INFRA_SSH_KEY="${INFRA_SSH_KEY:-/root/.ssh/id_ed25519_infra}"
INFRA_SSH_KEY_COMMENT="${INFRA_SSH_KEY_COMMENT:-infra@repo}"
INFRA_SSH_SKIP_PROMPT="${INFRA_SSH_SKIP_PROMPT:-0}"

DISK_VARS_FILE="${DISK_VARS_FILE:-/etc/infra/bootstrap-disk.env}"
DISK_VARS_REPO_PATH="${DISK_VARS_REPO_PATH:-bootstrap-disk.env}"
DISK_PROFILE_FETCH_FROM_REPO="${DISK_PROFILE_FETCH_FROM_REPO:-1}"

MAIN_DISK_DEVICE="${MAIN_DISK_DEVICE:-}"
