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
  # Lazy-load interactive + models
  source "${AIR_ROOT}/lib/core/interactive.sh"
  source "${AIR_ROOT}/lib/core/models.sh"

  # Non-TTY fallback
  if ! air_is_interactive; then
    header "ai-reviewer setup"
    info "Non-interactive environment detected."
    info "Configure manually with:"
    printf '\n' >&2
    info "  air config set provider <claude|openai|gemini>"
    info "  air config set api_key <your-key>"
    info "  air config set model <model-id>"
    printf '\n' >&2
    info "Or re-run in an interactive terminal: air config init"
    return 0
  fi

  header "ai-reviewer setup"

  # Step 1: Provider selection with status labels
  local current_provider current_key
  current_provider="$(config_get 'provider' 2>/dev/null || true)"
  current_key="$(config_get 'api_key' 2>/dev/null || true)"

  local claude_label="claude" openai_label="openai" gemini_label="gemini"
  if [[ "$current_provider" == "claude" ]] && [[ -n "$current_key" ]]; then
    claude_label="claude    [configured]"
  elif [[ "$current_provider" == "claude" ]]; then
    claude_label="claude    [no API key]"
  fi
  if [[ "$current_provider" == "openai" ]] && [[ -n "$current_key" ]]; then
    openai_label="openai    [configured]"
  elif [[ "$current_provider" == "openai" ]]; then
    openai_label="openai    [no API key]"
  fi
  if [[ "$current_provider" == "gemini" ]] && [[ -n "$current_key" ]]; then
    gemini_label="gemini    [configured]"
  elif [[ "$current_provider" == "gemini" ]]; then
    gemini_label="gemini    [no API key]"
  fi

  local provider
  air_menu "Step 1: Select AI provider" provider \
    "claude:${claude_label}" \
    "openai:${openai_label}" \
    "gemini:${gemini_label}" \
    "skip:skip" || {
    warn "No provider selected"
    return 0
  }

  if [[ "$provider" == "skip" ]]; then
    info "Skipped provider selection"
    _config_init_summary
    return 0
  fi

  global_config_set "provider" "$provider"
  success "Provider: ${provider}"

  # Step 2: API key
  printf '\n' >&2
  local api_key=""
  if [[ -n "$current_key" ]] && [[ "$current_provider" == "$provider" ]]; then
    local masked
    masked="$(_air_mask_value "$current_key")"
    info "Current API key: ${masked}"
    if air_confirm "Keep existing key?"; then
      api_key="$current_key"
      success "API key: kept"
    fi
  fi

  if [[ -z "$api_key" ]]; then
    info "Enter API key for ${provider}:"
    if air_secret "API key" api_key && [[ -n "$api_key" ]]; then
      global_config_set "api_key" "$api_key"
      success "API key: saved"
    else
      warn "No API key provided"
    fi
  fi

  # Step 3: Validate key in real time
  if [[ -n "$api_key" ]]; then
    printf '\n' >&2
    air_spinner_start "Validating API key..."
    local validate_rc=0
    ai_validate_key "$provider" "$api_key" || validate_rc=$?
    air_spinner_stop

    case $validate_rc in
      0) printf '  %s%s API key is valid%s\n' "${GREEN:-}" "✓" "${RESET:-}" >&2 ;;
      1) printf '  %s%s API key authentication failed%s\n' "${YELLOW:-}" "⚠" "${RESET:-}" >&2
         warn "Key was saved but may be incorrect. You can update later with: air config set api_key <key>" ;;
      2) printf '  %s%s Could not reach API (network error)%s\n' "${YELLOW:-}" "⚠" "${RESET:-}" >&2
         info "Key was saved. Validation will work when you have network access." ;;
    esac
  fi

  # Step 4: Model selection from catalog
  printf '\n' >&2
  local model="" default_model
  default_model="$(models_get_default "$provider")"

  # Build menu options from catalog
  local -a model_opts=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && model_opts+=("$line")
  done < <(models_get_display_list "$provider")

  # Add extra options
  if [[ "$provider" != "claude" ]]; then
    model_opts+=("_fetch:Fetch from API...")
  fi
  model_opts+=("_custom:Custom model ID...")

  air_menu "Step 4: Select model" model "${model_opts[@]}" || {
    model="$default_model"
  }

  # Handle special options
  if [[ "$model" == "_fetch" ]]; then
    air_spinner_start "Fetching models from ${provider} API..."
    if models_fetch_dynamic "$provider" "$api_key"; then
      air_spinner_stop "Models fetched"
      # Rebuild and re-prompt
      model_opts=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && model_opts+=("$line")
      done < <(models_get_display_list "$provider")
      model_opts+=("_custom:Custom model ID...")

      air_menu "Select model" model "${model_opts[@]}" || {
        model="$default_model"
      }
    else
      air_spinner_stop
      warn "Could not fetch models. Using catalog."
      model="$default_model"
    fi
  fi

  if [[ "$model" == "_custom" ]]; then
    air_input "Model ID" model "$default_model"
  fi

  if [[ -n "$model" ]]; then
    global_config_set "model" "$model"
    success "Model: ${model}"
  fi

  # Step 5: Summary
  _config_init_summary
}

_config_init_summary() {
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

  # Status summary
  local provider model api_key
  provider="$(config_get 'provider' 2>/dev/null || true)"
  model="$(config_get 'model' 2>/dev/null || true)"
  api_key="$(config_get 'api_key' 2>/dev/null || true)"

  printf '  ' >&2
  if [[ -n "$provider" ]] && [[ -n "$api_key" ]] && [[ -n "$model" ]]; then
    air_status_label "configured" >&2
    printf ' — ready to use\n' >&2
  elif [[ -n "$provider" ]]; then
    air_status_label "partial" >&2
    printf ' — some settings missing\n' >&2
  else
    air_status_label "missing" >&2
    printf '\n' >&2
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
