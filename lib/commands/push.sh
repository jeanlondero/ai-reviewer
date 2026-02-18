#!/usr/bin/env bash
# lib/commands/push.sh — Validate and push workflow.

command_push() {
  local validate_only=false
  local skip_review=false
  local pass_through_args=()

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --validate-only) validate_only=true; shift ;;
      --skip-review) skip_review=true; shift ;;
      --help|-h) _push_help; return 0 ;;
      *) pass_through_args+=("$1"); shift ;;
    esac
  done

  # Verify git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    die "Not in a git repository"
  fi

  # Verify remote exists
  if ! git remote get-url origin &>/dev/null; then
    die "No remote 'origin' configured"
  fi

  # Check for upstream branch
  local has_upstream=true
  if ! git rev-parse --abbrev-ref '@{upstream}' &>/dev/null 2>&1; then
    has_upstream=false
  fi

  # Collect unpushed commits
  local unpushed_commits=""
  if [[ "$has_upstream" == true ]]; then
    unpushed_commits="$(git log '@{upstream}..HEAD' --oneline 2>/dev/null)"
  else
    # No upstream — all commits on this branch are "unpushed"
    local default_branch
    default_branch="$(_push_detect_default_branch)"
    if [[ -n "$default_branch" ]]; then
      unpushed_commits="$(git log "origin/${default_branch}..HEAD" --oneline 2>/dev/null)"
    fi
  fi

  if [[ -z "$unpushed_commits" ]]; then
    warn "No commits to push"
    return 0
  fi

  local commit_count
  commit_count="$(printf '%s\n' "$unpushed_commits" | wc -l | tr -d ' ')"
  info "${commit_count} commit(s) to push:"
  printf '%s\n' "$unpushed_commits" >&2

  # Validate commit messages
  printf '\n' >&2
  info "Validating commit messages..."
  local lint_errors=0
  local commit_msg
  while IFS= read -r line; do
    # Remove hash prefix to get just the message
    commit_msg="${line#* }"
    if ! command_commit_lint "$commit_msg" 2>/dev/null; then
      warn "Invalid commit: ${commit_msg}"
      (( lint_errors++ ))
    fi
  done <<< "$unpushed_commits"

  if (( lint_errors > 0 )); then
    error "${lint_errors} commit message(s) failed validation"
    return 1
  fi
  success "All commit messages are valid"

  # AI review (if strict mode and not skipped)
  local strict
  strict="$(config_get 'review.strict' 'false')"
  if [[ "$strict" == "true" ]] && [[ "$skip_review" == false ]]; then
    printf '\n' >&2
    info "Running AI review (strict mode)..."
    local diff_ref
    if [[ "$has_upstream" == true ]]; then
      diff_ref="@{upstream}"
    else
      local default_branch
      default_branch="$(_push_detect_default_branch)"
      diff_ref="origin/${default_branch}"
    fi

    if ! command_ai_review --diff "$diff_ref" 2>/dev/null; then
      error "AI review flagged critical issues — push blocked"
      info "Use --skip-review to bypass"
      return 1
    fi
  fi

  # Execute push (unless validate-only)
  if [[ "$validate_only" == true ]]; then
    printf '\n' >&2
    success "Validation passed (validate-only mode)"
    return 0
  fi

  printf '\n' >&2
  info "Pushing..."
  if git push "${pass_through_args[@]+"${pass_through_args[@]}"}" 2>&1; then
    success "Push complete"
  else
    error "Push failed"
    return 1
  fi
}

_push_detect_default_branch() {
  local branch
  # Try to detect default branch from remote
  branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
  if [[ -n "$branch" ]]; then
    printf '%s' "$branch"
    return 0
  fi
  # Fallback: check for main/master
  if git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
    printf 'main'
  elif git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
    printf 'master'
  fi
}

_push_help() {
  cat >&2 <<EOF
${BOLD:-}air push${RESET:-} — Validate and push workflow

${BOLD:-}USAGE${RESET:-}
  air push [options] [-- git-push-args]

${BOLD:-}OPTIONS${RESET:-}
  --validate-only   Only validate, don't push (for hooks)
  --skip-review     Skip AI review
  --help            Show this help

${BOLD:-}DESCRIPTION${RESET:-}
  Validates commit messages (conventional commits), optionally runs
  AI review in strict mode, then pushes to remote.

  Any unrecognized arguments are passed through to git push.

${BOLD:-}EXAMPLES${RESET:-}
  ${DIM:-}air push${RESET:-}                     Validate + push
  ${DIM:-}air push --validate-only${RESET:-}      Just validate (for pre-push hook)
  ${DIM:-}air push --skip-review${RESET:-}        Skip AI review
  ${DIM:-}air push --set-upstream origin feat${RESET:-}   Pass args to git push
EOF
}
