# shellcheck shell=bash
#
# Загрузка переменных из .env в корне репозитория (публичный bootstrap).
#
# Единственный источник значений по умолчанию — корневой .env.
#
# Особенности:
#   • Переменные, уже заданные в окружении, НЕ перезаписываются (CLI/env > .env).
#   • Формат .env: KEY=VALUE (без пробелов вокруг `=`); комментарии — строкой,
#     начинающейся с «#». Значения можно обрамлять "…" или '…'.
#
# Подключение:
#   source "${ROOT}/scripts/lib/load-env.sh"

_infra_load_env_file() {
  local file="$1"
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"

    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"

    if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi

    if [[ -z "${!key+x}" ]]; then
      export "$key=$val"
    fi
  done < "$file"
}

_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_ENV_FILE="${_REPO_ROOT}/.env"

if [[ ! -f "${_ENV_FILE}" ]]; then
  echo "bootstrap: не найден файл ${_ENV_FILE}. Восстановите корневой .env из репозитория." >&2
  exit 1
fi

_infra_load_env_file "${_ENV_FILE}"

# Нормализация для шагов: внешний интерфейс — ENV и REF, внутри скриптов — *_VALUE
ENV_VALUE="${ENV:-ctl}"
REF_VALUE="${REF:-main}"

unset -f _infra_load_env_file
unset _REPO_ROOT _ENV_FILE
