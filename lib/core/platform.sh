#!/usr/bin/env bash
# lib/core/platform.sh — Platform detection and dependency checks.

[[ -n "${_AIR_PLATFORM_LOADED:-}" ]] && return 0
_AIR_PLATFORM_LOADED=1

detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos"   ;;
    Linux*)   echo "linux"   ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

check_bash_version() {
  local major="${BASH_VERSINFO[0]:-0}"
  if (( major < 4 )); then
    error "Bash 4+ required (found ${BASH_VERSION:-unknown})"
    info  "On macOS: brew install bash"
    return 1
  fi
  return 0
}

check_dependency() {
  local cmd="$1"
  command -v "$cmd" &>/dev/null
}

# Check a list of required dependencies.
# Usage: check_all_deps git curl jq
check_all_deps() {
  local missing=() cmd
  for cmd in "$@"; do
    if ! check_dependency "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    error "Missing required dependencies: ${missing[*]}"
    return 1
  fi
  return 0
}
