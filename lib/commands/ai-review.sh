#!/usr/bin/env bash
# lib/commands/ai-review.sh — AI-powered code review.

_AI_REVIEW_SYSTEM_PROMPT="You are an expert code reviewer. Review the following code changes and provide feedback.

Focus on:
- Bugs and logic errors
- Security vulnerabilities
- Performance issues
- Code quality and readability
- Best practices

Format your response as:
## Summary
Brief overview of the changes.

## Issues
List issues found, if any. For each issue:
- **[severity]** file:line — description

Severities: CRITICAL, WARNING, INFO

If no issues found, say 'No issues found.'"

_AI_REVIEW_MAX_LINES=10000
_AI_REVIEW_WARN_LINES=5000

command_ai_review() {
  local mode="staged"
  local diff_ref=""

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --staged) mode="staged"; shift ;;
      --diff)
        mode="diff"
        if [[ -z "${2:-}" ]]; then
          error "--diff requires a ref argument"
          return 1
        fi
        diff_ref="$2"
        shift 2
        ;;
      --help|-h) _ai_review_help; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Get diff
  local diff_content
  case "$mode" in
    staged)
      diff_content="$(git diff --cached 2>/dev/null)" || {
        die "Not in a git repository"
      }
      ;;
    diff)
      diff_content="$(git diff "$diff_ref" 2>/dev/null)" || {
        die "Failed to get diff against '${diff_ref}'"
      }
      ;;
  esac

  if [[ -z "$diff_content" ]]; then
    warn "No changes to review"
    if [[ "$mode" == "staged" ]]; then
      info "Stage changes first: git add <files>"
    fi
    return 0
  fi

  # Check diff size
  local line_count
  line_count="$(printf '%s\n' "$diff_content" | wc -l | tr -d ' ')"

  if (( line_count > _AI_REVIEW_MAX_LINES )); then
    warn "Diff is very large (${line_count} lines) — truncating to ${_AI_REVIEW_MAX_LINES} lines"
    diff_content="$(printf '%s\n' "$diff_content" | head -n "$_AI_REVIEW_MAX_LINES")"
  elif (( line_count > _AI_REVIEW_WARN_LINES )); then
    warn "Large diff (${line_count} lines) — review may take longer"
  fi

  # Build system prompt (base + skills if configured)
  local system_prompt="$_AI_REVIEW_SYSTEM_PROMPT"
  local skills_dir
  skills_dir="$(config_get 'review.skills_dir')"
  if [[ -n "$skills_dir" ]] && [[ -d "${AIR_PROJECT_ROOT:-.}/${skills_dir}" ]]; then
    local skills_path="${AIR_PROJECT_ROOT:-.}/${skills_dir}"
    local skill_file
    for skill_file in "${skills_path}"/*.md; do
      [[ -f "$skill_file" ]] || continue
      system_prompt="${system_prompt}"$'\n\n'"## Additional Review Guidelines"$'\n'"$(cat "$skill_file")"
    done
  fi

  # Build user prompt
  local user_prompt
  user_prompt="$(printf 'Review the following code changes:\n\n```diff\n%s\n```' "$diff_content")"

  # Call AI
  info "Reviewing changes (${line_count} lines)..."
  local response
  response="$(ai_call "$user_prompt" "$system_prompt")" || {
    error "AI review failed"
    return 1
  }

  # Display response
  printf '\n' >&2
  header "AI Review"
  printf '%s\n' "$response" >&2

  # Check strict mode
  local strict
  strict="$(config_get 'review.strict' 'false')"
  if [[ "$strict" == "true" ]]; then
    if printf '%s' "$response" | grep -qi 'CRITICAL'; then
      printf '\n' >&2
      error "Critical issues found (strict mode enabled)"
      return 1
    fi
  fi

  return 0
}

_ai_review_help() {
  cat >&2 <<EOF
${BOLD:-}air ai-review${RESET:-} — AI-powered code review

${BOLD:-}USAGE${RESET:-}
  air ai-review [options]

${BOLD:-}OPTIONS${RESET:-}
  --staged       Review staged changes (default)
  --diff <ref>   Review diff against a specific ref (branch, commit, tag)
  --help         Show this help

${BOLD:-}EXAMPLES${RESET:-}
  ${DIM:-}air ai-review${RESET:-}                Review staged changes
  ${DIM:-}air ai-review --diff main${RESET:-}     Review changes against main branch
  ${DIM:-}air ai-review --diff HEAD~3${RESET:-}   Review last 3 commits

${BOLD:-}CONFIG${RESET:-} (.ai-reviewer.yml)
  review:
    strict: false          # Exit 1 on critical issues
    skills_dir: docs/skills  # Directory with .md files for extra review guidelines
EOF
}
