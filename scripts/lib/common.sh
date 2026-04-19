# shellcheck shell=bash
#
# Общие утилиты для шагов start.sh (подключается сразу после load-env.sh).
#
# git_repo — обёртка над git с отключённым credential.helper, чтобы clone/fetch по HTTPS
# не блокировались интерактивным запросом пароля в неинтерактивном bootstrap.
# normalize_github_https_var_to_ssh / normalize_github_https_repo_url — github.com HTTPS → git@… (шаг 30, update.sh)
# dnf_install / distro_sync_system — единообразные вызовы dnf для шагов 20 и 90.

log_info() { echo "[+] $*"; }
log_warn() { echo "[!] $*"; }
log_err() { echo "[x] $*" >&2; }

section() { echo; echo "== $* =="; }

fail() {
  log_err "$*"
  exit 1
}

has_cmd() { command -v "$1" &>/dev/null; }

git_repo() {
  git -c credential.helper= "$@"
}

# Заменяет URL вида https://github.com/owner/repo в указанной переменной на git@github.com:owner/repo.git.
#
# @param $1 имя переменной (REPO_URL, PUBLIC_REPO_URL, …)
normalize_github_https_var_to_ssh() {
  local _name="$1"
  local -n _url_ref="${_name}"
  [[ -n "${_url_ref}" ]] || return 0
  if [[ "${_url_ref}" =~ ^https?://github\.com/([^/]+)/([^/]+)/?$ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    repo="${repo%.git}"
    _url_ref="git@github.com:${owner}/${repo}.git"
    log_info "${_name} приведён к SSH (github.com): ${_url_ref}"
  fi
}

# Заменяет REPO_URL вида https://github.com/owner/repo на git@github.com:owner/repo.git.
#
# @globals REPO_URL
normalize_github_https_repo_url() {
  normalize_github_https_var_to_ssh REPO_URL
}

dnf_install() {
  [[ "$#" -gt 0 ]] || return 0
  dnf install -y "$@"
}

distro_sync_system() {
  section "Синхронизация с репозиториями (distro-sync)"
  log_info "dnf distro-sync — полное выравнивание системы с доступными репозиториями."
  dnf distro-sync -y
}
