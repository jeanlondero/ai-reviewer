#!/usr/bin/env bash
# lib/commands/init.sh — Initialize ai-reviewer in a project.

command_init() {
  local force=false

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true; shift ;;
      --help|-h) _init_help; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  header "ai-reviewer init"

  local project_dir
  project_dir="$(pwd)"
  local config_file="${project_dir}/.ai-reviewer.yml"

  # Check if already initialized
  if [[ -f "$config_file" ]] && [[ "$force" == false ]]; then
    warn ".ai-reviewer.yml already exists in ${project_dir}"
    info "Use --force to overwrite"
    return 1
  fi

  # Generate .ai-reviewer.yml
  cat > "$config_file" <<'YAML'
provider: claude
model: claude-sonnet-4-20250514
review:
  strict: false
commit_lint:
  enabled: true
  types: [feat, fix, docs, chore, refactor, test, ci, style, perf, build]
  max_line_length: 72
YAML
  success "Created .ai-reviewer.yml"

  # Detect lefthook and offer hook installation
  if check_dependency lefthook; then
    _init_setup_lefthook "$project_dir"
  else
    info "Tip: install lefthook for git hook integration"
  fi

  # Summary
  printf '\n' >&2
  header "Setup complete"
  info "Next steps:"
  info "  1. Configure your AI provider: air config init"
  info "  2. Run health check: air doctor"
  info "  3. Try a review: air ai-review --staged"
}

_init_setup_lefthook() {
  local project_dir="$1"
  local lefthook_file="${project_dir}/lefthook.yml"

  if [[ -f "$lefthook_file" ]]; then
    info "lefthook.yml already exists, skipping hook setup"
    return 0
  fi

  printf '\n' >&2
  local install_hooks
  read -rp "$(printf '%s[info]%s Install git hooks via lefthook? [Y/n] ' "${CYAN}" "${RESET}")" install_hooks
  install_hooks="${install_hooks:-Y}"

  case "$install_hooks" in
    [Yy]|[Yy]es)
      cat > "$lefthook_file" <<'YAML'
commit-msg:
  commands:
    commit-lint:
      run: air commit-lint {1}
pre-push:
  commands:
    validate:
      run: air push --validate-only
YAML
      success "Created lefthook.yml"

      if lefthook install 2>/dev/null; then
        success "Git hooks installed"
      else
        warn "Failed to run lefthook install — run it manually"
      fi
      ;;
    *)
      info "Skipped hook installation"
      ;;
  esac
}

_init_help() {
  cat >&2 <<EOF
${BOLD:-}air init${RESET:-} — Initialize ai-reviewer in the current project

${BOLD:-}USAGE${RESET:-}
  air init [options]

${BOLD:-}OPTIONS${RESET:-}
  --force    Overwrite existing .ai-reviewer.yml
  --help     Show this help

${BOLD:-}DESCRIPTION${RESET:-}
  Creates .ai-reviewer.yml with default settings and optionally
  sets up git hooks via lefthook.
EOF
}
