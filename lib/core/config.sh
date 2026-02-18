#!/usr/bin/env bash
# lib/core/config.sh — Parse .ai-reviewer.yml configuration.
# Uses yq if available, falls back to pure bash parser.
# Stores values in associative array _AIR_CONFIG with dot notation keys.

[[ -n "${_AIR_CONFIG_LOADED:-}" ]] && return 0
_AIR_CONFIG_LOADED=1

declare -gA _AIR_CONFIG

config_load() {
  local config_file="${1:-${AIR_PROJECT_ROOT:-.}/.ai-reviewer.yml}"

  if [[ ! -f "$config_file" ]]; then
    return 1
  fi

  if command -v yq &>/dev/null; then
    _air_config_load_yq "$config_file"
  else
    _air_config_load_bash "$config_file"
  fi
}

config_get() {
  local key="$1"
  local default="${2:-}"

  # 1. Environment variable (highest priority)
  if declare -p _AIR_ENV_MAP &>/dev/null; then
    local env_var="${_AIR_ENV_MAP[$key]:-}"
    if [[ -n "$env_var" ]]; then
      local env_val="${!env_var:-}"
      if [[ -n "$env_val" ]]; then
        printf '%s' "$env_val"
        return 0
      fi
    fi
  fi

  # 2. Project config (.ai-reviewer.yml)
  if [[ -n "${_AIR_CONFIG[$key]:-}" ]]; then
    printf '%s' "${_AIR_CONFIG[$key]}"
    return 0
  fi

  # 3. Global config (~/.config/ai-reviewer/)
  if declare -p _AIR_GLOBAL_CONFIG &>/dev/null && [[ -n "${_AIR_GLOBAL_CONFIG[$key]:-}" ]]; then
    printf '%s' "${_AIR_GLOBAL_CONFIG[$key]}"
    return 0
  fi

  # 4. Default
  printf '%s' "$default"
}

config_get_source() {
  local key="$1"

  if declare -p _AIR_ENV_MAP &>/dev/null; then
    local env_var="${_AIR_ENV_MAP[$key]:-}"
    if [[ -n "$env_var" ]] && [[ -n "${!env_var:-}" ]]; then
      printf 'env'
      return 0
    fi
  fi

  if [[ -n "${_AIR_CONFIG[$key]:-}" ]]; then
    printf 'project'
    return 0
  fi

  if declare -p _AIR_GLOBAL_CONFIG &>/dev/null && [[ -n "${_AIR_GLOBAL_CONFIG[$key]:-}" ]]; then
    printf 'global'
    return 0
  fi

  printf 'default'
}

_air_config_load_yq() {
  local config_file="$1"
  local line key value

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    _AIR_CONFIG["$key"]="$value"
  done < <(yq eval '.. | select(tag != "!!map" and tag != "!!seq") | (path | join(".")) + "=" + (. // "")' "$config_file" 2>/dev/null)
}

_air_config_load_bash() {
  local config_file="$1"
  local raw_line line key value prefix="" indented=false

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    # Check indentation before trimming
    if [[ "$raw_line" =~ ^[[:space:]] ]]; then
      indented=true
    else
      indented=false
    fi

    # Trim leading/trailing whitespace
    line="${raw_line#"${raw_line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip empty and comments
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    # Detect map key (ends with :, no value)
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*):[[:space:]]*$ ]]; then
      if [[ "$indented" == false ]]; then
        prefix="${BASH_REMATCH[1]}."
      fi
      continue
    fi

    # Key: value pair
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*):[[:space:]]+(.+)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Remove inline comment
      if [[ "$value" != \"*\" ]] && [[ "$value" != \'*\' ]]; then
        value="${value%%#*}"
      fi

      # Trim value
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      # Remove quotes
      if [[ "$value" == \"*\" ]]; then
        value="${value#\"}"
        value="${value%\"}"
      elif [[ "$value" == \'*\' ]]; then
        value="${value#\'}"
        value="${value%\'}"
      fi

      if [[ "$indented" == true ]] && [[ -n "$prefix" ]]; then
        _AIR_CONFIG["${prefix}${key}"]="$value"
      else
        prefix=""
        _AIR_CONFIG["$key"]="$value"
      fi
      continue
    fi

    # Reset prefix on non-indented lines
    if [[ "$indented" == false ]]; then
      prefix=""
    fi
  done < "$config_file"
}
