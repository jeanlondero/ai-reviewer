#!/usr/bin/env bash
# lib/commands/commit-lint.sh — Validate conventional commit messages.

command_commit_lint() {
  local message=""

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) _commit_lint_help; return 0 ;;
      -*) error "Unknown option: $1"; return 1 ;;
      *)
        # Argument is a file path containing the commit message
        if [[ -f "$1" ]]; then
          message="$(cat "$1")"
        else
          message="$1"
        fi
        shift
        ;;
    esac
  done

  # Read from stdin if no argument
  if [[ -z "$message" ]] && [[ ! -t 0 ]]; then
    message="$(cat)"
  fi

  # Auto-detect from .git/COMMIT_EDITMSG
  if [[ -z "$message" ]]; then
    local commit_msg_file
    commit_msg_file="$(git rev-parse --git-dir 2>/dev/null)/COMMIT_EDITMSG"
    if [[ -f "$commit_msg_file" ]]; then
      message="$(cat "$commit_msg_file")"
    fi
  fi

  if [[ -z "$message" ]]; then
    error "No commit message provided"
    info "Usage: air commit-lint <file|message>, or pipe via stdin"
    return 1
  fi

  # Strip comment lines (lines starting with #)
  local cleaned_message
  cleaned_message="$(printf '%s\n' "$message" | grep -v '^#' || true)"

  # Get first line (subject)
  local subject
  subject="$(printf '%s\n' "$cleaned_message" | head -n1)"

  if [[ -z "$subject" ]]; then
    error "Commit message is empty"
    return 1
  fi

  # Load config with defaults
  local allowed_types max_line_length scope_required
  allowed_types="$(config_get 'commit_lint.types' 'feat,fix,docs,chore,refactor,test,ci,style,perf,build')"
  max_line_length="$(config_get 'commit_lint.max_line_length' '72')"
  scope_required="$(config_get 'commit_lint.scope_required' 'false')"

  # Normalize types: strip brackets/spaces for YAML array format [a, b, c]
  allowed_types="${allowed_types#\[}"
  allowed_types="${allowed_types%\]}"
  allowed_types="$(printf '%s' "$allowed_types" | tr -d ' ')"

  # Validate
  local errors=0

  # Parse: type(scope)?: description
  local cc_regex='^([a-zA-Z]+)(\([a-zA-Z0-9-]+\))?(!)?: (.+)$'
  if [[ ! "$subject" =~ $cc_regex ]]; then
    error "Invalid format: expected 'type(scope): description' or 'type: description'"
    info "  Got: ${subject}"
    (( errors++ ))
  else
    local msg_type="${BASH_REMATCH[1]}"
    local msg_scope="${BASH_REMATCH[2]}"
    local msg_description="${BASH_REMATCH[4]}"

    # Validate type is allowed
    local type_valid=false
    local IFS=','
    local t
    for t in $allowed_types; do
      if [[ "$t" == "$msg_type" ]]; then
        type_valid=true
        break
      fi
    done
    unset IFS

    if [[ "$type_valid" == false ]]; then
      error "Unknown type '${msg_type}'"
      info "  Allowed: ${allowed_types}"
      (( errors++ ))
    fi

    # Scope required check
    if [[ "$scope_required" == "true" ]] && [[ -z "$msg_scope" ]]; then
      error "Scope is required but missing"
      info "  Expected: ${msg_type}(scope): ${msg_description}"
      (( errors++ ))
    fi

    # Description must start with lowercase
    if [[ -n "$msg_description" ]] && [[ "$msg_description" =~ ^[A-Z] ]]; then
      error "Description must start with lowercase"
      info "  Got: '${msg_description}'"
      (( errors++ ))
    fi

    # Description must not end with period
    if [[ "$msg_description" =~ \.$ ]]; then
      error "Description must not end with a period"
      (( errors++ ))
    fi
  fi

  # Check max line length
  local subject_len=${#subject}
  if (( subject_len > max_line_length )); then
    error "Subject line too long: ${subject_len}/${max_line_length} characters"
    (( errors++ ))
  fi

  if (( errors > 0 )); then
    return 1
  fi

  success "Commit message is valid"
  return 0
}

_commit_lint_help() {
  cat >&2 <<EOF
${BOLD:-}air commit-lint${RESET:-} — Validate conventional commit messages

${BOLD:-}USAGE${RESET:-}
  air commit-lint <file>          Read message from file
  air commit-lint <message>       Validate message string
  echo "feat: msg" | air commit-lint   Read from stdin
  air commit-lint                 Auto-detect .git/COMMIT_EDITMSG

${BOLD:-}OPTIONS${RESET:-}
  --help     Show this help

${BOLD:-}FORMAT${RESET:-}
  type(scope): description

  type    — One of: feat, fix, docs, chore, refactor, test, ci, style, perf, build
  scope   — Optional alphanumeric scope (e.g., auth, api)
  description — Lowercase start, no trailing period

${BOLD:-}CONFIG${RESET:-} (.ai-reviewer.yml)
  commit_lint:
    types: [feat, fix, docs, ...]   # Allowed types
    max_line_length: 72             # Max subject line length
    scope_required: false           # Require scope
EOF
}
