#!/usr/bin/env bash
# lib/commands/_stub.sh — Generic "not implemented yet" helper.

[[ -n "${_AIR_STUB_LOADED:-}" ]] && return 0
_AIR_STUB_LOADED=1

command_stub() {
  local cmd_name="${1:-command}"
  warn "'${cmd_name}' is not implemented yet."
  info "This command will be available in a future release."
  return 1
}
