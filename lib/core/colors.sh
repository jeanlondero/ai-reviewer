#!/usr/bin/env bash
# lib/core/colors.sh — Terminal colors and output helpers.
# All output goes to stderr to keep stdout clean for piping.
# shellcheck disable=SC2034  # Color vars are used by consumers of this lib

[[ -n "${_AIR_COLORS_LOADED:-}" ]] && return 0
_AIR_COLORS_LOADED=1

_air_init_colors() {
  if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RESET=""
  else
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    MAGENTA=$'\033[0;35m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
  fi
}

_air_init_colors

info()    { printf '%s[info]%s %s\n' "${CYAN}" "${RESET}" "$*" >&2; }
warn()    { printf '%s[warn]%s %s\n' "${YELLOW}" "${RESET}" "$*" >&2; }
error()   { printf '%s[error]%s %s\n' "${RED}" "${RESET}" "$*" >&2; }
success() { printf '%s[ok]%s %s\n' "${GREEN}" "${RESET}" "$*" >&2; }

die() {
  error "$@"
  exit 1
}

header() {
  printf '\n%s%s══ %s ══%s\n\n' "${BOLD}" "${MAGENTA}" "$*" "${RESET}" >&2
}
