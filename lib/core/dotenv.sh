#!/usr/bin/env bash
# lib/core/dotenv.sh — Load .env files (port of dotenv_loader.rb).
# Does NOT override existing environment variables.

[[ -n "${_AIR_DOTENV_LOADED:-}" ]] && return 0
_AIR_DOTENV_LOADED=1

dotenv_load() {
  local root="${1:-${AIR_PROJECT_ROOT:-}}"

  if [[ -z "$root" ]]; then
    air_find_project_root 2>/dev/null || return 0
    root="${AIR_PROJECT_ROOT:-}"
    [[ -z "$root" ]] && return 0
  fi

  local file
  for file in ".env" ".env.development"; do
    _air_dotenv_parse_file "${root}/${file}"
  done
}

_air_dotenv_parse_file() {
  local filepath="$1"
  [[ -f "$filepath" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    # Split on first =
    key="${line%%=*}"
    value="${line#*=}"

    # No = found
    [[ "$key" == "$line" ]] && continue

    # Trim key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    # Remove inline comment (not inside quotes)
    if [[ "$value" != \"*\" ]] && [[ "$value" != \'*\' ]]; then
      value="${value%%#*}"
    fi

    # Trim value
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Remove surrounding quotes
    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == \'*\' ]]; then
      value="${value#\'}"
      value="${value%\'}"
    fi

    # Only set if not already in environment
    if [[ -z "${!key+x}" ]]; then
      export "$key=$value"
    fi
  done < "$filepath"
}
