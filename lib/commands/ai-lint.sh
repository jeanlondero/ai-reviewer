#!/usr/bin/env bash
# lib/commands/ai-lint.sh — AI lint via git hooks.

_AI_LINT_SYSTEM_PROMPT="You are a fast code linter. Only flag obvious bugs, security issues, and typos. Be brief.

Format: one issue per line, like:
- [CRITICAL] file:line — description
- [WARNING] file:line — description

If no issues, respond with exactly: No issues found."

command_ai_lint() {
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) _ai_lint_help; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Get staged files
  local staged_files
  staged_files="$(git diff --cached --name-only 2>/dev/null)" || {
    die "Not in a git repository"
  }

  if [[ -z "$staged_files" ]]; then
    return 0
  fi

  # Get staged diff
  local diff_content
  diff_content="$(git diff --cached 2>/dev/null)"

  if [[ -z "$diff_content" ]]; then
    return 0
  fi

  local file_count
  file_count="$(printf '%s\n' "$staged_files" | wc -l | tr -d ' ')"

  # Build prompt
  local user_prompt
  user_prompt="$(printf 'Lint the following staged changes (%s files):\n\nFiles:\n%s\n\n```diff\n%s\n```' \
    "$file_count" "$staged_files" "$diff_content")"

  info "Linting ${file_count} staged file(s)..."
  local response
  response="$(ai_call "$user_prompt" "$_AI_LINT_SYSTEM_PROMPT")" || {
    error "AI lint failed"
    return 1
  }

  # Display response compactly
  if printf '%s' "$response" | grep -qi 'no issues found'; then
    success "No issues found"
    return 0
  fi

  # Show issues
  printf '%s\n' "$response" >&2

  # Check strict mode
  local strict
  strict="$(config_get 'review.strict' 'false')"
  if [[ "$strict" == "true" ]]; then
    if printf '%s' "$response" | grep -qi 'CRITICAL'; then
      error "Critical issues found (strict mode)"
      return 1
    fi
  fi

  return 0
}

_ai_lint_help() {
  cat >&2 <<EOF
${BOLD:-}air ai-lint${RESET:-} — AI lint for git hooks

${BOLD:-}USAGE${RESET:-}
  air ai-lint [options]

${BOLD:-}OPTIONS${RESET:-}
  --help     Show this help

${BOLD:-}DESCRIPTION${RESET:-}
  Quick AI lint of staged changes. Designed for pre-commit hooks.
  Focuses on obvious bugs, security issues, and typos.

  If no files are staged, exits silently with code 0.

${BOLD:-}CONFIG${RESET:-} (.ai-reviewer.yml)
  review:
    strict: false   # Exit 1 on critical issues (blocks commit)
EOF
}
