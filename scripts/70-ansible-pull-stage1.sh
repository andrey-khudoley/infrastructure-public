# shellcheck shell=bash
#
# Шаг 70 — запуск приватного репозитория после клона.
#
# Историческое имя файла («ansible-pull-stage1») сохранено для совместимости путей
# в документации и скриптах; фактически выполняются две цели Make в корне клона:
#
#   make -C "${PULL_DIR}" install-deps   # install-python-deps (constraints.txt) + коллекции Galaxy
#   make -C "${PULL_DIR}" bootstrap      # фаза stage1 единого playbooks/site.yml
#
# Контракт с приватным репозиторием:
#   • В корне клона должен быть Makefile с целями «install-deps» и «bootstrap».
#   • Цель «bootstrap» запускает фазу stage1 (эквивалент: ansible-playbook
#     playbooks/site.yml --tags stage1 -e env="${ENV}").
#   • Обновление только infra-sync.env и infra-*.service|timer после git pull — «make apply-infra-units»
#     (см. приватный Makefile); на узле без полного bootstrap вызывается из update.sh.
#   • Дальнейшие фазы (stage2, runtime) запускаются через таймеры systemd, которые
#     ставятся задачами из роли bootstrap (см. приватный README).
#
# Окружение для make (экспорт перед вызовами):
#   REPO_URL, REF, ENV, PULL_DIR — контекст bootstrap (ветка/репо/каталог клона).
#   Имя REF в окружении — исторически ожидаемое приватным Makefile; значение берётся
#   из REF_VALUE (REF в shell — ветка из REF=… при запуске и из .env).
#   GALAXY_* и COLLECTIONS_REQ — параметры офлайн-установки коллекций Galaxy.
#
# Подшаг в subshell «( )»: изолировать cd в PULL_DIR и не менять cwd родительского
# процесса start.sh.

# Выполняет «make install-deps» и «make bootstrap» в каталоге клона с экспортом
# контрактных переменных окружения.
#
# @globals PULL_DIR REPO_URL REF_VALUE ENV_VALUE GALAXY_* COLLECTIONS_REQ
# @return код возврата последней цели make (install-deps или bootstrap)
# @exit   через fail, если нет Makefile
run_stage1_ansible_pull() {
  section "Приватный репозиторий: make install-deps + make bootstrap"
  local mk="${PULL_DIR}/Makefile"
  [[ -f "${mk}" ]] || fail "Не найден ${mk}. В корне приватного репозитория должен быть Makefile (цели install-deps и bootstrap)."
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
    make bootstrap
  )
}

# Точка входа шага 70: пропуск при SKIP_ANSIBLE=1.
#
# @globals SKIP_ANSIBLE
# @return 0 при пропуске или после успешного make install-deps + make bootstrap
step_ansible_pull_stage1() {
  if [[ "${SKIP_ANSIBLE}" == "1" ]]; then
    log_info "SKIP_ANSIBLE=1: make install-deps/bootstrap в приватном репозитории пропущены."
    return 0
  fi
  run_stage1_ansible_pull
}
