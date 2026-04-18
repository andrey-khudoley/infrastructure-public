# shellcheck shell=bash
#
# Шаг 70 — запуск приватного репозитория после клона.
#
# Историческое имя файла («ansible-pull-stage1») сохранено для совместимости путей
# в документации и скриптах; фактически вызывается не ansible-pull, а цель Make:
#
#   make -C "${PULL_DIR}" start
#
# Контракт с приватным репозиторием:
#   • В корне клона должен быть Makefile с целью «start».
#   • Цель «start» определяет всё прикладное поведение: установка коллекций Galaxy,
#     ansible-playbook, теги и т.д. — на стороне приватного репо.
#
# Окружение для make (экспорт перед «make start»):
#   REPO_URL, REF, ENV, PULL_DIR — контекст bootstrap (ветка/репо/каталог клона).
#   Имя REF в окружении — исторически ожидаемое приватным Makefile; значение берётся
#   из REF_VALUE (переменная REF в shell до env.sh — это ветка из REF=… при запуске).
#   GALAXY_* и COLLECTIONS_REQ — опционально для целей вроде ansible-galaxy install;
#   приватный Makefile может их игнорировать, если не нужны.
#
# Подшаг в subshell «( )»: изолировать cd в PULL_DIR и не менять cwd родительского
# процесса start.sh.

# Выполняет «make start» в каталоге клона с экспортом контрактных переменных окружения.
#
# @globals PULL_DIR REPO_URL REF_VALUE ENV_VALUE GALAXY_* COLLECTIONS_REQ
# @return код возврата make
# @exit   через fail, если нет Makefile
run_stage1_ansible_pull() {
  section "Приватный репозиторий: make start"
  local mk="${PULL_DIR}/Makefile"
  [[ -f "${mk}" ]] || fail "Не найден ${mk}. В корне приватного репозитория должен быть Makefile (цель start)."
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
    make start
  )
}

# Точка входа шага 70: пропуск при SKIP_ANSIBLE=1.
#
# @globals SKIP_ANSIBLE
# @return 0 при пропуске или после успешного make start
step_ansible_pull_stage1() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: make start в приватном репозитории пропущен."
    return 0
  fi
  run_stage1_ansible_pull
}
