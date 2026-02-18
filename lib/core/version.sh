#!/usr/bin/env bash
# lib/core/version.sh — Version management.

[[ -n "${_AIR_VERSION_LOADED:-}" ]] && return 0
_AIR_VERSION_LOADED=1

air_version() {
  local version_file="${AIR_ROOT}/VERSION"
  if [[ -f "$version_file" ]]; then
    cat "$version_file" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

air_print_version() {
  printf '%sai-reviewer%s %s\n' "${BOLD:-}" "${RESET:-}" "$(air_version)"
}

air_check_update() {
  local current remote_version url
  current="$(air_version)"
  url="https://raw.githubusercontent.com/jeanlondero/ai-reviewer/main/VERSION"

  remote_version="$(curl -fsSL --connect-timeout 3 --max-time 3 "$url" 2>/dev/null | tr -d '[:space:]')" || return 0

  if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$current" ]]; then
    warn "Update available: ${current} → ${remote_version}"
    info "Run: ai-reviewer update"
  fi
}
