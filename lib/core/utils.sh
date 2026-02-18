#!/usr/bin/env bash
# lib/core/utils.sh — Utility functions.
# shellcheck disable=SC2034  # AIR_PROJECT_ROOT is used by consumers

[[ -n "${_AIR_UTILS_LOADED:-}" ]] && return 0
_AIR_UTILS_LOADED=1

# Walk up from CWD looking for .ai-reviewer.yml or .git.
# Sets AIR_PROJECT_ROOT on success.
air_find_project_root() {
  local dir
  dir="$(pwd)"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.ai-reviewer.yml" ]] || [[ -d "$dir/.git" ]]; then
      AIR_PROJECT_ROOT="$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}
