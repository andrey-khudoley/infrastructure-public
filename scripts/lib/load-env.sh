# shellcheck shell=bash
#
# Загрузка переменных из config/*.env в корне репозитория (публичный bootstrap).
#
# Источник значений по умолчанию — файлы в каталоге config/ (в т.ч. опциональный config/disk.env).
#
# Особенности:
#   • Переменные, уже заданные в окружении, НЕ перезаписываются (CLI/env > config).
#   • Отсутствующий файл пропускается без ошибки.
#   • Формат: KEY=VALUE (без пробелов вокруг `=`); комментарии — строкой,
#     начинающейся с «#». Значения можно обрамлять "…" или '…'.
#
# Подключение:
#   source "${ROOT}/scripts/lib/load-env.sh"

_infra_load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

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
for _f in host.env repos.env ssh.env galaxy.env disk.env; do
  _infra_load_env_file "${_REPO_ROOT}/config/${_f}"
done

# Нормализация для шагов: внешний интерфейс — REF, внутри скриптов — *_VALUE
REF_VALUE="${REF:-main}"
PUBLIC_REF_VALUE="${PUBLIC_REF:-main}"

unset -f _infra_load_env_file
unset _REPO_ROOT _f
