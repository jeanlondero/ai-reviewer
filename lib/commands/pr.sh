#!/usr/bin/env bash
# lib/commands/pr.sh — Create pull request with AI-generated content.

_PR_SYSTEM_PROMPT="You are a PR description writer. Generate a concise PR title and description.

Format your response exactly like this:
TITLE: <concise title under 70 chars>

BODY:
## Summary
<1-3 bullet points describing what changed and why>

## Changes
<bullet list of specific changes>

## Test plan
<bullet list of testing steps>

Keep it concise and focused on what matters for reviewers."

command_pr() {
  local base_branch=""
  local draft=false
  local yes=false

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        if [[ -z "${2:-}" ]]; then
          error "--base requires a branch name"
          return 1
        fi
        base_branch="$2"
        shift 2
        ;;
      --draft) draft=true; shift ;;
      --yes|-y) yes=true; shift ;;
      --help|-h) _pr_help; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Require gh CLI
  if ! check_dependency gh; then
    die "GitHub CLI (gh) is required — install from https://cli.github.com"
  fi

  # Verify git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    die "Not in a git repository"
  fi

  # Detect base branch
  if [[ -z "$base_branch" ]]; then
    base_branch="$(_pr_detect_base_branch)"
    if [[ -z "$base_branch" ]]; then
      die "Could not detect base branch — use --base <branch>"
    fi
  fi

  info "Base branch: ${base_branch}"

  # Get merge base and diff
  local merge_base
  merge_base="$(git merge-base HEAD "origin/${base_branch}" 2>/dev/null)" || {
    die "Cannot find merge base with origin/${base_branch} — fetch first?"
  }

  local diff_content
  diff_content="$(git diff "${merge_base}..HEAD" 2>/dev/null)"

  if [[ -z "$diff_content" ]]; then
    die "No changes found against ${base_branch}"
  fi

  # Get commit messages
  local commit_messages
  commit_messages="$(git log "origin/${base_branch}..HEAD" --format='%s' 2>/dev/null)"

  local commit_count
  commit_count="$(printf '%s\n' "$commit_messages" | wc -l | tr -d ' ')"
  info "${commit_count} commit(s) to include"

  # Build prompt
  local user_prompt
  user_prompt="$(printf 'Generate a PR title and description for these changes.\n\nCommit messages:\n%s\n\nDiff:\n```diff\n%s\n```' \
    "$commit_messages" "$diff_content")"

  # Truncate diff if too large (keep commit messages readable)
  local diff_lines
  diff_lines="$(printf '%s\n' "$diff_content" | wc -l | tr -d ' ')"
  if (( diff_lines > 5000 )); then
    warn "Diff is large (${diff_lines} lines) — truncating for AI"
    local truncated_diff
    truncated_diff="$(printf '%s\n' "$diff_content" | head -n 5000)"
    user_prompt="$(printf 'Generate a PR title and description for these changes.\n\nCommit messages:\n%s\n\nDiff (truncated):\n```diff\n%s\n```' \
      "$commit_messages" "$truncated_diff")"
  fi

  info "Generating PR content..."
  local response
  response="$(ai_call "$user_prompt" "$_PR_SYSTEM_PROMPT")" || {
    error "Failed to generate PR content"
    return 1
  }

  # Parse response
  local pr_title pr_body
  pr_title="$(_pr_extract_title "$response")"
  pr_body="$(_pr_extract_body "$response")"

  # Fallback if parsing fails
  if [[ -z "$pr_title" ]]; then
    pr_title="$(printf '%s\n' "$commit_messages" | head -n1)"
  fi
  if [[ -z "$pr_body" ]]; then
    pr_body="$response"
  fi

  # Preview
  printf '\n' >&2
  header "PR Preview"
  printf '%s%sTitle:%s %s\n' "${BOLD}" "${CYAN}" "${RESET}" "$pr_title" >&2
  printf '\n' >&2
  printf '%s\n' "$pr_body" >&2

  # Confirm (unless --yes)
  if [[ "$yes" == false ]]; then
    printf '\n' >&2
    local confirm
    read -rp "$(printf '%s[info]%s Create this PR? [Y/n] ' "${CYAN}" "${RESET}")" confirm
    confirm="${confirm:-Y}"
    case "$confirm" in
      [Yy]|[Yy]es) ;;
      *)
        info "PR creation cancelled"
        return 0
        ;;
    esac
  fi

  # Build gh pr create command
  local gh_args=(pr create --title "$pr_title" --body "$pr_body" --base "$base_branch")
  if [[ "$draft" == true ]]; then
    gh_args+=(--draft)
  fi

  info "Creating PR..."
  if gh "${gh_args[@]}" 2>&1; then
    success "PR created"
  else
    error "Failed to create PR"
    return 1
  fi
}

_pr_detect_base_branch() {
  # Try symbolic ref
  local branch
  branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
  if [[ -n "$branch" ]]; then
    printf '%s' "$branch"
    return 0
  fi
  # Check for main or master
  if git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
    printf 'main'
  elif git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
    printf 'master'
  fi
}

_pr_extract_title() {
  local response="$1"
  # Look for "TITLE: ..." line
  local title
  title="$(printf '%s\n' "$response" | sed -n 's/^TITLE:[[:space:]]*//p' | head -n1)"
  printf '%s' "$title"
}

_pr_extract_body() {
  local response="$1"
  # Everything after "BODY:" line
  local body
  body="$(printf '%s\n' "$response" | sed -n '/^BODY:/,$ { /^BODY:/d; p; }')"
  printf '%s' "$body"
}

_pr_help() {
  cat >&2 <<EOF
${BOLD:-}air pr${RESET:-} — Create pull request with AI-generated content

${BOLD:-}USAGE${RESET:-}
  air pr [options]

${BOLD:-}OPTIONS${RESET:-}
  --base <branch>   Base branch (default: auto-detect main/master)
  --draft           Create as draft PR
  --yes, -y         Skip confirmation prompt
  --help            Show this help

${BOLD:-}DESCRIPTION${RESET:-}
  Generates a PR title and description using AI based on the diff
  and commit messages, then creates the PR via GitHub CLI (gh).

${BOLD:-}REQUIREMENTS${RESET:-}
  Requires the GitHub CLI (gh) — https://cli.github.com

${BOLD:-}EXAMPLES${RESET:-}
  ${DIM:-}air pr${RESET:-}                  Create PR against auto-detected base
  ${DIM:-}air pr --draft${RESET:-}           Create as draft
  ${DIM:-}air pr --base develop${RESET:-}    Use 'develop' as base branch
  ${DIM:-}air pr --yes${RESET:-}             Skip confirmation
EOF
}
