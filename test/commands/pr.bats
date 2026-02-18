#!/usr/bin/env bats
# test/commands/pr.bats — Tests for lib/commands/pr.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_CONFIG_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_AI_CLIENT_LOADED _AIR_PLATFORM_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AI_REVIEW_PROVIDER AI_REVIEW_MODEL AI_REVIEW_API_KEY
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/platform.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/core/ai_client.sh"
  source "${AIR_ROOT}/lib/commands/pr.sh"
  global_config_load
}

@test "pr: --help shows usage" {
  run command_pr --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "--base"
  assert_output --partial "--draft"
  assert_output --partial "--yes"
}

@test "pr: fails if gh is not installed" {
  # Override check_dependency to simulate missing gh
  check_dependency() {
    [[ "$1" != "gh" ]]
  }
  export -f check_dependency

  run command_pr
  assert_failure
  assert_output --partial "gh"
}

@test "pr: fails if not in a git repo" {
  cd /tmp
  run command_pr
  assert_failure
}

@test "pr: --base requires argument" {
  run command_pr --base
  assert_failure
  assert_output --partial "requires a branch"
}

@test "pr: rejects unknown option" {
  run command_pr --invalid
  assert_failure
  assert_output --partial "Unknown option"
}

@test "pr: extracts title from AI response" {
  local response="TITLE: feat: add authentication flow

BODY:
## Summary
- Added OAuth2 authentication"

  run _pr_extract_title "$response"
  assert_success
  assert_output "feat: add authentication flow"
}

@test "pr: extracts body from AI response" {
  local response="TITLE: feat: add auth

BODY:
## Summary
- Added OAuth2"

  run _pr_extract_body "$response"
  assert_success
  assert_output --partial "## Summary"
  assert_output --partial "OAuth2"
}

@test "pr: detects base branch from remote" {
  cd "${TEST_TEMP_DIR}"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt
  git add f.txt
  git commit -q -m "init"

  # Create a fake remote ref
  git branch main 2>/dev/null || true
  mkdir -p .git/refs/remotes/origin
  cp .git/refs/heads/main .git/refs/remotes/origin/main 2>/dev/null || \
  cp .git/refs/heads/master .git/refs/remotes/origin/master 2>/dev/null || true

  run _pr_detect_base_branch
  assert_success
  # Should find main or master
  [[ "$output" == "main" || "$output" == "master" ]]
}
