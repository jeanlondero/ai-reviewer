#!/usr/bin/env bash
# lib/core/interactive.sh — Interactive TUI primitives for ai-reviewer.
# Provides: menu, confirm, input, secret, spinner, status labels.
# All output goes to stderr. Graceful fallback when not TTY.
# Lazy-loaded — not sourced at startup.

[[ -n "${_AIR_INTERACTIVE_LOADED:-}" ]] && return 0
_AIR_INTERACTIVE_LOADED=1

# --- TTY detection ---

air_is_interactive() {
  [[ -t 0 ]] && [[ -t 2 ]]
}

# --- Menu selection ---
# Usage: air_menu <prompt> <var_name> <opts...>
# Opts format: "value:Label text"
# Sets variable via printf -v. Returns: 0=ok, 1=not-interactive, 2=cancelled

air_menu() {
  local prompt="$1" var_name="$2"
  shift 2
  local -a opts=("$@")

  if ! air_is_interactive; then
    return 1
  fi

  local count=${#opts[@]}
  if (( count == 0 )); then
    return 1
  fi

  printf '\n  %s%s%s\n' "${BOLD:-}" "$prompt" "${RESET:-}" >&2

  local i value label
  for (( i = 0; i < count; i++ )); do
    value="${opts[$i]%%:*}"
    label="${opts[$i]#*:}"
    printf '  %s%d)%s %s\n' "${BOLD:-}" $(( i + 1 )) "${RESET:-}" "$label" >&2
  done
  printf '\n' >&2

  local choice
  read -rp "  Choice [1]: " choice <&0 2>&2
  choice="${choice:-1}"

  # Handle quit/cancel
  case "$choice" in
    q|Q|quit|cancel) return 2 ;;
  esac

  # Validate numeric
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count )); then
    printf '  %sInvalid choice%s\n' "${RED:-}" "${RESET:-}" >&2
    return 2
  fi

  value="${opts[$(( choice - 1 ))]%%:*}"
  printf -v "$var_name" '%s' "$value"
  return 0
}

# --- Confirm prompt ---
# Usage: air_confirm <prompt> [default:Y]
# Returns: 0=yes, 1=no

air_confirm() {
  local prompt="$1"
  local default="${2:-Y}"

  local hint
  if [[ "${default^^}" == "Y" ]]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi

  if ! air_is_interactive; then
    [[ "${default^^}" == "Y" ]] && return 0 || return 1
  fi

  local answer
  read -rp "  ${prompt} ${hint} " answer <&0 2>&2
  answer="${answer:-$default}"

  case "${answer^^}" in
    Y|YES) return 0 ;;
    *)     return 1 ;;
  esac
}

# --- Text input ---
# Usage: air_input <prompt> <var_name> [default]

air_input() {
  local prompt="$1" var_name="$2" default="${3:-}"

  if ! air_is_interactive; then
    if [[ -n "$default" ]]; then
      printf -v "$var_name" '%s' "$default"
      return 0
    fi
    return 1
  fi

  local display_prompt="  ${prompt}"
  if [[ -n "$default" ]]; then
    display_prompt="${display_prompt} [${default}]"
  fi
  display_prompt="${display_prompt}: "

  local value
  read -rp "$display_prompt" value <&0 2>&2
  value="${value:-$default}"
  printf -v "$var_name" '%s' "$value"
  return 0
}

# --- Secret input (no echo) ---
# Usage: air_secret <prompt> <var_name>
# Returns: 0=ok, 1=not-interactive

air_secret() {
  local prompt="$1" var_name="$2"

  if ! air_is_interactive; then
    return 1
  fi

  local value
  read -rsp "  ${prompt}: " value <&0 2>&2
  printf '\n' >&2
  printf -v "$var_name" '%s' "$value"
  return 0
}

# --- Spinner ---

_AIR_SPINNER_PID=""

air_spinner_start() {
  local message="${1:-Working...}"

  if ! air_is_interactive; then
    printf '  %s...\n' "$message" >&2
    return 0
  fi

  # Spinner characters
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

  (
    local i=0
    while true; do
      printf '\r  %s %s' "${frames[$i]}" "$message" >&2
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.1
    done
  ) &
  _AIR_SPINNER_PID=$!

  # Ensure cleanup on signals
  trap 'air_spinner_stop' INT TERM
}

air_spinner_stop() {
  local success_msg="${1:-}"

  if [[ -n "$_AIR_SPINNER_PID" ]]; then
    kill "$_AIR_SPINNER_PID" 2>/dev/null
    wait "$_AIR_SPINNER_PID" 2>/dev/null
    _AIR_SPINNER_PID=""
  fi

  # Clear spinner line
  if air_is_interactive; then
    printf '\r\033[K' >&2
  fi

  if [[ -n "$success_msg" ]]; then
    printf '  %s%s%s\n' "${GREEN:-}" "$success_msg" "${RESET:-}" >&2
  fi

  trap - INT TERM
}

# --- Status label ---
# Usage: air_status_label <configured|partial|missing>
# Outputs inline colored label (no newline)

air_status_label() {
  local status="$1"
  case "$status" in
    configured)
      printf '%s%s configured%s' "${GREEN:-}" "✓" "${RESET:-}"
      ;;
    partial)
      printf '%s%s partial%s' "${YELLOW:-}" "⚠" "${RESET:-}"
      ;;
    missing)
      printf '%s%s not configured%s' "${RED:-}" "✗" "${RESET:-}"
      ;;
    *)
      printf '%s' "$status"
      ;;
  esac
}
