# shellcheck shell=bash
#
# Значения по умолчанию для bootstrap (публичный репозиторий).
#
# Подключается из start.sh первым. Любую переменную можно переопределить окружением
# перед запуском: переменные shell присваиваются здесь как ENV_VAR="${ENV_VAR:-default}".
#
# Соглашения имён:
#   ENV_VALUE, REF_VALUE — нормализованные значения после чтения ENV и REF из окружения
#   пользователя; в шаге 70 в процесс make экспортируются именно ENV и REF (см. README).
#
# См. README.md — таблица переменных и примеры вызова.

# --- Приватный репозиторий и ref (шаг 50, 70) ---
ENV_VALUE="${ENV:-ctl}"                                    # ctl | stage | prod → export ENV для make install-deps/bootstrap
REPO_URL="${REPO_URL:-https://github.com/andrey-khudoley/infrastructure-private.git}"
REF_VALUE="${REF:-main}"                                   # ветка, тег или коммит для git и для export REF=
PULL_DIR="${PULL_DIR:-/var/lib/infra/src}"                  # каталог клона; рабочая директория для make install-deps/bootstrap
SKIP_ANSIBLE="${SKIP_ANSIBLE:-0}"                          # 1 — без клона и без make install-deps/bootstrap (только ОС/диски)

# --- Опции для ansible-galaxy / Makefile в приватном репо (прокидываются в шаге 70) ---
GALAXY_INSTALL_TIMEOUT="${GALAXY_INSTALL_TIMEOUT:-300}"
GALAXY_DOWNLOAD_DIR="${GALAXY_DOWNLOAD_DIR:-/var/lib/infra/galaxy-download}"
GALAXY_INSTALL_RETRIES="${GALAXY_INSTALL_RETRIES:-5}"
GALAXY_RETRY_SLEEP_SEC="${GALAXY_RETRY_SLEEP_SEC:-10}"

# --- SSH deploy key (шаг 30), если REPO_URL — git@ или ssh:// ---
INFRA_SSH_KEY="${INFRA_SSH_KEY:-/root/.ssh/id_ed25519_infra}"
INFRA_SSH_KEY_COMMENT="${INFRA_SSH_KEY_COMMENT:-infra@repo}"
INFRA_SSH_SKIP_PROMPT="${INFRA_SSH_SKIP_PROMPT:-0}"

# --- Профиль дисков (шаг 40) ---
DISK_VARS_FILE="${DISK_VARS_FILE:-/etc/infra/bootstrap-disk.env}"
DISK_VARS_REPO_PATH="${DISK_VARS_REPO_PATH:-bootstrap-disk.env}"
DISK_PROFILE_FETCH_FROM_REPO="${DISK_PROFILE_FETCH_FROM_REPO:-1}"

MAIN_DISK_DEVICE="${MAIN_DISK_DEVICE:-}"
