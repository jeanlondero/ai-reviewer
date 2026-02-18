#!/usr/bin/env bash
# lib/commands/config.sh — Manage global ai-reviewer configuration.

command_config() {
  local subcmd="${1:-help}"
  shift 2>/dev/null || true

  case "$subcmd" in
    set)    _config_cmd_set "$@" ;;
    get)    _config_cmd_get "$@" ;;
    unset)  _config_cmd_unset "$@" ;;
    list)   _config_cmd_list ;;
    path)   _config_cmd_path ;;
    edit)   _config_cmd_edit ;;
    init)   _config_cmd_init ;;
    help|--help|-h)  _config_cmd_help ;;
    *)
      error "Unknown config subcommand: ${subcmd}"
      info "Run 'air config help' for usage"
      return 1
      ;;
  esac
}

_config_cmd_set() {
  if [[ $# -lt 2 ]]; then
    error "Usage: air config set <key> <value>"
    return 1
  fi
  local key="$1" value="$2"
  global_config_set "$key" "$value"
  success "Set ${key}"
}

_config_cmd_get() {
  if [[ $# -lt 1 ]]; then
    error "Usage: air config get <key>"
    return 1
  fi
  local key="$1"
  local value source
  value="$(config_get "$key")"
  source="$(config_get_source "$key")"

  if [[ -z "$value" ]]; then
    warn "${key}: not set"
    return 1
  fi

  if _air_is_secret_key "$key" && [[ "$source" != "env" ]]; then
    printf '%s\n' "$(_air_mask_value "$value")"
  else
    printf '%s\n' "$value"
  fi
  info "(source: ${source})" >&2
}

_config_cmd_unset() {
  if [[ $# -lt 1 ]]; then
    error "Usage: air config unset <key>"
    return 1
  fi
  local key="$1"
  if global_config_unset "$key"; then
    success "Unset ${key}"
  else
    warn "${key}: not found in global config"
    return 1
  fi
}

_config_cmd_list() {
  header "Global configuration"
  local output
  output="$(global_config_list)"
  if [[ -z "$output" ]]; then
    warn "No configuration set. Run 'air config init' to get started."
    return 0
  fi
  printf '%s\n' "$output"
}

_config_cmd_path() {
  _air_global_config_dir
  printf '\n'
}

_config_cmd_edit() {
  local editor="${EDITOR:-vi}"
  local config_file
  config_file="$(_air_global_config_file)"

  if [[ ! -f "$config_file" ]]; then
    # Create empty config file so editor has something to open
    _air_global_ensure_config_dir >/dev/null
    touch "$config_file"
    chmod 644 "$config_file"
  fi

  info "Opening ${config_file} with ${editor}..."
  "$editor" "$config_file"
}

_config_cmd_init() {
  header "ai-reviewer setup"
  printf '\n' >&2

  # 1. Select provider
  info "Select AI provider:"
  printf '  %s1)%s claude\n' "${BOLD:-}" "${RESET:-}" >&2
  printf '  %s2)%s openai\n' "${BOLD:-}" "${RESET:-}" >&2
  printf '  %s3)%s gemini\n' "${BOLD:-}" "${RESET:-}" >&2
  printf '  %s4)%s skip\n' "${BOLD:-}" "${RESET:-}" >&2
  printf '\n' >&2

  local provider_choice
  read -rp "Choice [1]: " provider_choice
  provider_choice="${provider_choice:-1}"

  local provider=""
  case "$provider_choice" in
    1) provider="claude" ;;
    2) provider="openai" ;;
    3) provider="gemini" ;;
    4|skip) provider="" ;;
    *) warn "Invalid choice, skipping provider"; provider="" ;;
  esac

  if [[ -n "$provider" ]]; then
    global_config_set "provider" "$provider"
    success "Provider: ${provider}"

    # 2. API key
    printf '\n' >&2
    info "Enter API key for ${provider}:"
    local api_key
    read -rsp "API key: " api_key
    printf '\n' >&2

    if [[ -n "$api_key" ]]; then
      global_config_set "api_key" "$api_key"
      success "API key: saved"
    else
      warn "No API key provided, skipping"
    fi

    # 3. Model
    local default_model
    case "$provider" in
      claude) default_model="claude-sonnet-4-20250514" ;;
      openai) default_model="gpt-4o" ;;
      gemini) default_model="gemini-2.0-flash" ;;
      *)      default_model="" ;;
    esac

    printf '\n' >&2
    local model
    read -rp "Model [${default_model}]: " model
    model="${model:-$default_model}"

    if [[ -n "$model" ]]; then
      global_config_set "model" "$model"
      success "Model: ${model}"
    fi
  fi

  # Summary
  printf '\n' >&2
  header "Configuration saved"
  local dir
  dir="$(_air_global_config_dir)"
  info "Config dir: ${dir}"

  local output
  output="$(global_config_list)"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  fi

  printf '\n' >&2
  info "Run 'air config list' to view, 'air config set <key> <value>' to change"
}

_config_cmd_help() {
  cat >&2 <<EOF
${BOLD:-}air config${RESET:-} — Manage global configuration

${BOLD:-}USAGE${RESET:-}
  air config <subcommand> [args]

${BOLD:-}SUBCOMMANDS${RESET:-}
  ${GREEN:-}set${RESET:-} <key> <value>   Save a value to global config
  ${GREEN:-}get${RESET:-} <key>            Get a value (respects cascade: env > project > global)
  ${GREEN:-}unset${RESET:-} <key>          Remove a key from global config
  ${GREEN:-}list${RESET:-}                 List all global config values
  ${GREEN:-}path${RESET:-}                 Print config directory path
  ${GREEN:-}edit${RESET:-}                 Open config file in \$EDITOR
  ${GREEN:-}init${RESET:-}                 Interactive setup wizard
  ${GREEN:-}help${RESET:-}                 Show this help

${BOLD:-}KEYS${RESET:-}
  provider    AI provider (claude, openai, gemini)
  api_key     API key for the provider (stored securely)
  model       Model to use
  strict      Block push on critical issues (true/false)

${BOLD:-}EXAMPLES${RESET:-}
  ${DIM:-}air config init${RESET:-}                 Interactive setup
  ${DIM:-}air config set provider claude${RESET:-}   Set provider
  ${DIM:-}air config get provider${RESET:-}           Get resolved value
  ${DIM:-}air config list${RESET:-}                  List all values

${BOLD:-}CASCADE${RESET:-}
  Values are resolved in order: env vars > .ai-reviewer.yml > global config
EOF
}
