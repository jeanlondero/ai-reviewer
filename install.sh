#!/usr/bin/env bash
# install.sh — Self-contained installer for ai-reviewer.
# Usage: curl -fsSL https://raw.githubusercontent.com/jeanlondero/ai-reviewer/main/install.sh | bash

set -euo pipefail

# --- Inline colors (no deps) ---
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]]; then
  RED="" GREEN="" YELLOW="" BLUE="" CYAN="" BOLD="" DIM="" RESET=""
else
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
fi

info()    { printf '%s[info]%s %s\n' "${CYAN}" "${RESET}" "$*" >&2; }
warn()    { printf '%s[warn]%s %s\n' "${YELLOW}" "${RESET}" "$*" >&2; }
error()   { printf '%s[error]%s %s\n' "${RED}" "${RESET}" "$*" >&2; }
success() { printf '%s[ok]%s %s\n' "${GREEN}" "${RESET}" "$*" >&2; }
die()     { error "$@"; exit 1; }

# --- Platform detection ---
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
    die "Bash 4+ required (found ${BASH_VERSION:-unknown}). On macOS: brew install bash"
  fi
}

# --- Config ---
REPO_URL="https://github.com/jeanlondero/ai-reviewer.git"
INSTALL_DIR="${AI_REVIEWER_HOME:-${HOME}/.ai-reviewer}"

# --- Main ---
main() {
  printf '\n%s%s══ ai-reviewer installer ══%s\n\n' "${BOLD}" "${BLUE}" "${RESET}" >&2

  # Platform checks
  local os
  os="$(detect_os)"
  info "Platform: ${os} ($(uname -m))"
  check_bash_version

  # Require git
  if ! command -v git &>/dev/null; then
    die "git is required. Please install git and try again."
  fi

  # Require curl
  if ! command -v curl &>/dev/null; then
    die "curl is required. Please install curl and try again."
  fi

  # Clone or update
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    info "Updating existing installation at ${INSTALL_DIR}..."
    git -C "${INSTALL_DIR}" pull --rebase --quiet || die "Failed to update"
    success "Updated ai-reviewer"
  else
    if [[ -d "${INSTALL_DIR}" ]]; then
      warn "Directory ${INSTALL_DIR} exists but is not a git repo. Removing..."
      rm -rf "${INSTALL_DIR}"
    fi
    info "Cloning ai-reviewer to ${INSTALL_DIR}..."
    git clone --depth 1 "${REPO_URL}" "${INSTALL_DIR}" --quiet || die "Failed to clone"
    success "Installed ai-reviewer"
  fi

  # Make executable
  chmod +x "${INSTALL_DIR}/bin/ai-reviewer"

  # Determine bin directory for symlinks
  local bin_dir=""
  if [[ -d "/usr/local/bin" ]] && [[ -w "/usr/local/bin" ]]; then
    bin_dir="/usr/local/bin"
  elif [[ -d "${HOME}/.local/bin" ]]; then
    bin_dir="${HOME}/.local/bin"
  else
    mkdir -p "${HOME}/.local/bin"
    bin_dir="${HOME}/.local/bin"
  fi

  info "Creating symlinks in ${bin_dir}..."
  ln -sf "${INSTALL_DIR}/bin/ai-reviewer" "${bin_dir}/ai-reviewer"
  ln -sf "${INSTALL_DIR}/bin/ai-reviewer" "${bin_dir}/air"
  success "Symlinks created: ai-reviewer, air"

  # Check optional deps
  printf '\n' >&2
  info "Optional dependencies:"
  local optional_deps=(gh jq fzf lefthook yq shellcheck)
  local dep
  for dep in "${optional_deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
      success "  ${dep}: $(command -v "$dep")"
    else
      warn "  ${dep}: not found (optional)"
    fi
  done

  # Verify PATH
  printf '\n' >&2
  if echo "$PATH" | tr ':' '\n' | grep -qx "$bin_dir"; then
    success "PATH includes ${bin_dir}"
  else
    warn "${bin_dir} is not in your PATH"
    info "Add to your shell profile:"
    # shellcheck disable=SC2016  # Intentional: show literal $PATH to user
    printf '\n  %sexport PATH="%s:$PATH"%s\n\n' "${DIM}" "${bin_dir}" "${RESET}" >&2
  fi

  # Done
  printf '%s%s══ Installation complete ══%s\n\n' "${BOLD}" "${GREEN}" "${RESET}" >&2
  info "Run 'air config init' to configure your AI provider"
  info "Run 'ai-reviewer doctor' to verify your setup"
  info "Run 'ai-reviewer help' for usage"
}

main "$@"
