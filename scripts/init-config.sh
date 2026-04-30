#!/usr/bin/env bash
# shellcheck shell=bash
#
# Развёртывание рабочих config/*.env и config/disk.env из шаблонов *.example.
# Жёсткая перезапись существующих файлов. Вызывается: make init
#
# @return 0 при успехе

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

_pairs=(
  "config/host.env.example:config/host.env"
  "config/repos.env.example:config/repos.env"
  "config/ssh.env.example:config/ssh.env"
  "config/galaxy.env.example:config/galaxy.env"
  "config/disk.env.example:config/disk.env"
)

for _pair in "${_pairs[@]}"; do
  _src="${_pair%%:*}"
  _dst="${_pair##*:}"
  if [[ ! -f "${_src}" ]]; then
    echo "[!] Нет шаблона ${_src}" >&2
    exit 1
  fi
  cp -f "${_src}" "${_dst}"
  echo "[+] ${_dst} <- ${_src}"
done

echo "[+] init-config: готово."
