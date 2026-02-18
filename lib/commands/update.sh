#!/usr/bin/env bash
# lib/commands/update.sh — Self-update ai-reviewer.

command_update() {
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) _update_help; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  header "ai-reviewer update"

  # Verify AIR_ROOT is a git repo
  if [[ ! -d "${AIR_ROOT}/.git" ]]; then
    die "Not a git installation — cannot self-update. Reinstall via git clone."
  fi

  local current_version
  current_version="$(air_version)"
  info "Current version: ${current_version}"

  # Fetch latest
  info "Checking for updates..."
  if ! git -C "$AIR_ROOT" fetch --quiet 2>/dev/null; then
    die "Failed to fetch updates — check your network connection"
  fi

  # Compare local vs remote VERSION
  local remote_version
  remote_version="$(git -C "$AIR_ROOT" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')" || true

  if [[ -z "$remote_version" ]]; then
    # Try master branch
    remote_version="$(git -C "$AIR_ROOT" show origin/master:VERSION 2>/dev/null | tr -d '[:space:]')" || true
  fi

  if [[ -z "$remote_version" ]]; then
    warn "Could not read remote version"
    info "Pulling latest changes anyway..."
  elif [[ "$remote_version" == "$current_version" ]]; then
    success "Already up to date (v${current_version})"
    return 0
  else
    info "Update available: ${current_version} -> ${remote_version}"
  fi

  # Pull latest
  if ! git -C "$AIR_ROOT" pull --rebase --quiet 2>/dev/null; then
    die "Failed to pull updates — resolve conflicts manually"
  fi

  # Re-read version after update
  local new_version
  new_version="$(cat "${AIR_ROOT}/VERSION" 2>/dev/null | tr -d '[:space:]')"
  new_version="${new_version:-unknown}"

  # Ensure bin is executable
  if [[ -f "${AIR_ROOT}/bin/ai-reviewer" ]]; then
    chmod +x "${AIR_ROOT}/bin/ai-reviewer"
  fi

  success "Updated: v${current_version} -> v${new_version}"
}

_update_help() {
  cat >&2 <<EOF
${BOLD:-}air update${RESET:-} — Self-update ai-reviewer

${BOLD:-}USAGE${RESET:-}
  air update [options]

${BOLD:-}OPTIONS${RESET:-}
  --help     Show this help

${BOLD:-}DESCRIPTION${RESET:-}
  Fetches and applies the latest version from the git remote.
  Requires ai-reviewer to be installed via git clone.
EOF
}
