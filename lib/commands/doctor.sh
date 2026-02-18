#!/usr/bin/env bash
# lib/commands/doctor.sh — Health check: OS, bash, deps, config, .env.

command_doctor() {
  local issues=0

  header "ai-reviewer doctor"

  # --- OS ---
  local os
  os="$(detect_os)"
  success "OS: ${os} ($(uname -m))"

  # --- Bash version ---
  if check_bash_version 2>/dev/null; then
    success "Bash: ${BASH_VERSION}"
  else
    error "Bash: ${BASH_VERSION:-unknown} (4+ required)"
    (( issues++ ))
  fi

  # --- Required deps ---
  local required_deps=(git curl)
  local dep
  for dep in "${required_deps[@]}"; do
    if check_dependency "$dep"; then
      success "${dep}: $(command -v "$dep")"
    else
      error "${dep}: not found"
      (( issues++ ))
    fi
  done

  # --- Optional deps ---
  printf '\n' >&2
  info "Optional dependencies:"
  local optional_deps=(gh jq fzf lefthook yq shellcheck)
  for dep in "${optional_deps[@]}"; do
    if check_dependency "$dep"; then
      success "  ${dep}: $(command -v "$dep")"
    else
      warn "  ${dep}: not found"
    fi
  done

  # --- Project root ---
  printf '\n' >&2
  info "Project detection:"
  if air_find_project_root 2>/dev/null; then
    success "  Project root: ${AIR_PROJECT_ROOT}"
  else
    warn "  No project root found (no .ai-reviewer.yml or .git)"
  fi

  # --- Config ---
  local config_file="${AIR_PROJECT_ROOT:-.}/.ai-reviewer.yml"
  if [[ -f "$config_file" ]]; then
    success "  Config: ${config_file}"
    config_load "$config_file" 2>/dev/null
  else
    warn "  Config: .ai-reviewer.yml not found"
  fi

  # --- .env ---
  local env_file="${AIR_PROJECT_ROOT:-.}/.env"
  if [[ -f "$env_file" ]]; then
    success "  .env: ${env_file}"
  else
    warn "  .env: not found"
  fi

  # --- Global configuration ---
  printf '\n' >&2
  info "Global configuration:"
  local global_dir
  global_dir="$(_air_global_config_dir)"
  success "  Config dir: ${global_dir}"

  local global_config_file
  global_config_file="$(_air_global_config_file)"
  if [[ -f "$global_config_file" ]]; then
    success "  Config file: ${global_config_file}"
  else
    warn "  Config file: not found"
  fi

  local global_creds_file
  global_creds_file="$(_air_global_credentials_file)"
  if [[ -f "$global_creds_file" ]]; then
    local creds_perms
    creds_perms="$(stat -f '%Lp' "$global_creds_file" 2>/dev/null || stat -c '%a' "$global_creds_file" 2>/dev/null || echo "unknown")"
    if [[ "$creds_perms" == "600" ]]; then
      success "  Credentials: ${global_creds_file} (mode ${creds_perms})"
    else
      warn "  Credentials: ${global_creds_file} (mode ${creds_perms}, expected 600)"
      (( issues++ ))
    fi
  else
    warn "  Credentials: not found"
  fi

  # --- AI provider (cascade) ---
  printf '\n' >&2
  info "AI provider:"
  local resolved_provider resolved_source
  resolved_provider="$(config_get 'provider')"
  resolved_source="$(config_get_source 'provider')"
  if [[ -n "$resolved_provider" ]]; then
    success "  provider=${resolved_provider} (source: ${resolved_source})"
  else
    warn "  provider: not set"
  fi

  local resolved_model model_source
  resolved_model="$(config_get 'model')"
  model_source="$(config_get_source 'model')"
  if [[ -n "$resolved_model" ]]; then
    success "  model=${resolved_model} (source: ${model_source})"
  else
    warn "  model: not set"
  fi

  local has_key key_source
  has_key="$(config_get 'api_key')"
  key_source="$(config_get_source 'api_key')"
  if [[ -n "$has_key" ]]; then
    success "  api_key=****${has_key: -4} (source: ${key_source})"
  else
    warn "  api_key: not set"
  fi

  # --- Summary ---
  printf '\n' >&2
  if (( issues == 0 )); then
    success "All checks passed!"
  else
    error "${issues} issue(s) found"
  fi

  return "$issues"
}
