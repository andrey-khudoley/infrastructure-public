# shellcheck shell=bash
#
# Шаг 70 — установка зависимостей приватного репозитория.
#
# В корне клона должен быть Makefile с целью «install-deps»:
#
#   make -C "${PULL_DIR}" install-deps   # .venv (config/constraints.txt) + Galaxy-коллекции
#
# Запуск ansible-playbook (фазы stage1/stage2/runtime) — отдельный ручной шаг
# пользователя через `make stage1 ENV=...` в корне клона. Никаких systemd
# юнитов и автоматических переходов между фазами bootstrap здесь не делает.
#
# Контракт с приватным репозиторием:
#   • В корне клона должен быть Makefile с целью «install-deps».
#   • Цель «install-deps» создаёт .venv с ansible-core (config/constraints.txt) и
#     устанавливает коллекции Galaxy.
#
# Окружение для make (экспорт перед вызовом):
#   REPO_URL, REF, ENV, PULL_DIR — контекст узла (ветка/репо/каталог клона).
#   GALAXY_* и COLLECTIONS_REQ — параметры офлайн-установки коллекций Galaxy.
#
# Подшаг в subshell «( )»: изолировать cd в PULL_DIR и не менять cwd
# родительского процесса run-start.sh.

# Выполняет «make install-deps» в каталоге клона с экспортом контрактных
# переменных окружения.
#
# @globals PULL_DIR REPO_URL REF_VALUE ENV_VALUE GALAXY_* COLLECTIONS_REQ
# @return код возврата make install-deps
# @exit   через fail, если нет Makefile
run_install_deps() {
  section "Приватный репозиторий: make install-deps"
  local mk="${PULL_DIR}/Makefile"
  [[ -f "${mk}" ]] || fail "Не найден ${mk}. В корне приватного репозитория должен быть Makefile (цель install-deps)."
  (
    cd "${PULL_DIR}"
    export REPO_URL="${REPO_URL}"
    export REF="${REF_VALUE}"
    export ENV="${ENV_VALUE}"
    export PULL_DIR="${PULL_DIR}"
    export GALAXY_DOWNLOAD_DIR="${GALAXY_DOWNLOAD_DIR}"
    export GALAXY_INSTALL_TIMEOUT="${GALAXY_INSTALL_TIMEOUT}"
    export GALAXY_INSTALL_RETRIES="${GALAXY_INSTALL_RETRIES}"
    export GALAXY_RETRY_SLEEP_SEC="${GALAXY_RETRY_SLEEP_SEC}"
    export COLLECTIONS_REQ="${COLLECTIONS_REQ:-${PULL_DIR}/collections/requirements.yml}"
    make install-deps
  )
}

# Точка входа шага 70: пропуск при SKIP_ANSIBLE=1.
#
# @globals SKIP_ANSIBLE
# @return 0 при пропуске или после успешного make install-deps
step_install_deps() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: make install-deps в приватном репозитории пропущен."
    return 0
  fi
  run_install_deps
}
