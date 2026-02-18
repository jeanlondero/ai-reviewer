#!/usr/bin/env bats
# test/commands/ai-review.bats — Tests for lib/commands/ai-review.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_CONFIG_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_AI_CLIENT_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AI_REVIEW_PROVIDER AI_REVIEW_MODEL AI_REVIEW_API_KEY
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/core/ai_client.sh"
  source "${AIR_ROOT}/lib/commands/ai-review.sh"
  global_config_load

  # Create a test git repo
  cd "${TEST_TEMP_DIR}"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "initial"
}

@test "ai-review: warns when no staged changes" {
  run command_ai_review
  assert_success
  assert_output --partial "No changes to review"
}

@test "ai-review: warns to stage changes" {
  run command_ai_review --staged
  assert_output --partial "Stage changes"
}

@test "ai-review: --help shows usage" {
  run command_ai_review --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "--staged"
  assert_output --partial "--diff"
}

@test "ai-review: rejects unknown option" {
  run command_ai_review --invalid
  assert_failure
  assert_output --partial "Unknown option"
}

@test "ai-review: --diff requires ref argument" {
  run command_ai_review --diff
  assert_failure
  assert_output --partial "requires a ref"
}

@test "ai-review: detects staged changes and calls AI" {
  # Stage a change
  echo "modified" > file.txt
  git add file.txt

  # Mock ai_call to avoid real API calls
  ai_call() {
    echo "## Summary"
    echo "Minor change detected."
    echo "## Issues"
    echo "No issues found."
  }
  export -f ai_call

  run command_ai_review
  assert_success
  assert_output --partial "Reviewing changes"
  assert_output --partial "AI Review"
  assert_output --partial "No issues found"
}

@test "ai-review: strict mode fails on CRITICAL issues" {
  echo "modified" > file.txt
  git add file.txt

  # Mock config to enable strict mode
  _AIR_CONFIG["review.strict"]="true"

  # Mock ai_call to return critical issue
  ai_call() {
    echo "## Issues"
    echo "- **[CRITICAL]** file.txt:1 — SQL injection vulnerability"
  }
  export -f ai_call

  run command_ai_review
  assert_failure
  assert_output --partial "Critical issues found"
}

@test "ai-review: non-strict mode passes even with critical issues" {
  echo "modified" > file.txt
  git add file.txt

  # Mock ai_call to return critical issue
  ai_call() {
    echo "## Issues"
    echo "- **[CRITICAL]** file.txt:1 — SQL injection vulnerability"
  }
  export -f ai_call

  run command_ai_review
  assert_success
}
