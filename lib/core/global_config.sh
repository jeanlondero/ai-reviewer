#!/usr/bin/env bash
# lib/core/global_config.sh — Global config store for ai-reviewer.
# Manages two files:
#   config      — shareable settings (chmod 644)
#   credentials — secrets like API keys (chmod 600)
# Format: KEY=VALUE (same as .env, trivial to parse in bash)

[[ -n "${_AIR_GLOBAL_CONFIG_LOADED:-}" ]] && return 0
_AIR_GLOBAL_CONFIG_LOADED=1

declare -gA _AIR_GLOBAL_CONFIG

# Keys that are stored in the credentials file (secrets)
declare -ga _AIR_SECRET_KEYS=("api_key")

# Map: config key → environment variable name
declare -gA _AIR_ENV_MAP=(
  [provider]="AI_REVIEW_PROVIDER"
  [api_key]="AI_REVIEW_API_KEY"
  [model]="AI_REVIEW_MODEL"
  [strict]="AI_REVIEW_STRICT"
)

# --- Private helpers ---

_air_global_config_dir() {
  printf '%s' "${AIR_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ai-reviewer}"
}

_air_global_ensure_config_dir() {
  local dir
  dir="$(_air_global_config_dir)"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    chmod 700 "$dir"
  fi
  printf '%s' "$dir"
}

_air_global_config_file() {
  printf '%s/config' "$(_air_global_config_dir)"
}

_air_global_credentials_file() {
  printf '%s/credentials' "$(_air_global_config_dir)"
}

_air_is_secret_key() {
  local key="$1"
  local secret
  for secret in "${_AIR_SECRET_KEYS[@]}"; do
    [[ "$key" == "$secret" ]] && return 0
  done
  return 1
}

_air_mask_value() {
  local value="$1"
  local len=${#value}
  if (( len <= 4 )); then
    printf '****'
  else
    local tail="${value: -4}"
    printf '****%s' "$tail"
  fi
}

_air_global_parse_file() {
  local filepath="$1"
  [[ ! -f "$filepath" ]] && return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip empty and comments
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    # Must contain =
    [[ "$line" != *=* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"

    # Trim key/value whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Remove surrounding quotes from value
    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == \'*\' ]]; then
      value="${value#\'}"
      value="${value%\'}"
    fi

    [[ -z "$key" ]] && continue
    _AIR_GLOBAL_CONFIG["$key"]="$value"
  done < "$filepath"
}

_air_global_write_key() {
  local filepath="$1" key="$2" value="$3"
  local tmpfile dir

  dir="$(dirname "$filepath")"
  tmpfile="$(mktemp "${dir}/.tmp.XXXXXX")"
  trap 'rm -f "$tmpfile"' EXIT

  # If file exists, copy all lines except the one being set
  if [[ -f "$filepath" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      local lkey="${line%%=*}"
      # Trim key whitespace
      lkey="${lkey#"${lkey%%[![:space:]]*}"}"
      lkey="${lkey%"${lkey##*[![:space:]]}"}"
      [[ "$lkey" == "$key" ]] && continue
      printf '%s\n' "$line"
    done < "$filepath" > "$tmpfile"
  fi

  # Append new key=value
  printf '%s=%s\n' "$key" "$value" >> "$tmpfile"

  mv -f "$tmpfile" "$filepath"
  trap - EXIT

  # Enforce permissions
  if [[ "$filepath" == *"/credentials" ]]; then
    chmod 600 "$filepath"
  else
    chmod 644 "$filepath"
  fi
}

_air_global_remove_key() {
  local filepath="$1" key="$2"
  [[ ! -f "$filepath" ]] && return 1

  local tmpfile dir
  dir="$(dirname "$filepath")"
  tmpfile="$(mktemp "${dir}/.tmp.XXXXXX")"
  trap 'rm -f "$tmpfile"' EXIT

  local found=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    local lkey="${line%%=*}"
    lkey="${lkey#"${lkey%%[![:space:]]*}"}"
    lkey="${lkey%"${lkey##*[![:space:]]}"}"
    if [[ "$lkey" == "$key" ]]; then
      found=true
      continue
    fi
    printf '%s\n' "$line"
  done < "$filepath" > "$tmpfile"

  mv -f "$tmpfile" "$filepath"
  trap - EXIT

  # Enforce permissions
  if [[ "$filepath" == *"/credentials" ]]; then
    chmod 600 "$filepath"
  else
    chmod 644 "$filepath"
  fi

  [[ "$found" == true ]]
}

# --- Public API ---

global_config_load() {
  _AIR_GLOBAL_CONFIG=()
  _air_global_parse_file "$(_air_global_config_file)"
  _air_global_parse_file "$(_air_global_credentials_file)"
}

global_config_get() {
  local key="$1"
  printf '%s' "${_AIR_GLOBAL_CONFIG[$key]:-}"
}

global_config_set() {
  local key="$1" value="$2"

  _air_global_ensure_config_dir >/dev/null

  if _air_is_secret_key "$key"; then
    _air_global_write_key "$(_air_global_credentials_file)" "$key" "$value"
  else
    _air_global_write_key "$(_air_global_config_file)" "$key" "$value"
  fi

  _AIR_GLOBAL_CONFIG["$key"]="$value"
}

global_config_unset() {
  local key="$1"
  local removed=false

  if _air_global_remove_key "$(_air_global_config_file)" "$key"; then
    removed=true
  fi
  if _air_global_remove_key "$(_air_global_credentials_file)" "$key"; then
    removed=true
  fi

  unset "_AIR_GLOBAL_CONFIG[$key]"

  [[ "$removed" == true ]]
}

global_config_list() {
  local key value
  for key in $(printf '%s\n' "${!_AIR_GLOBAL_CONFIG[@]}" | sort); do
    value="${_AIR_GLOBAL_CONFIG[$key]}"
    if _air_is_secret_key "$key"; then
      value="$(_air_mask_value "$value")"
    fi
    printf '%s=%s\n' "$key" "$value"
  done
}
