#!/usr/bin/env bats
# test/commands/ai-lint.bats — Tests for lib/commands/ai-lint.sh

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
  source "${AIR_ROOT}/lib/commands/ai-lint.sh"
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

@test "ai-lint: exits silently when no staged files" {
  run command_ai_lint
  assert_success
  refute_output --partial "Linting"
}

@test "ai-lint: --help shows usage" {
  run command_ai_lint --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "pre-commit"
}

@test "ai-lint: rejects unknown option" {
  run command_ai_lint --invalid
  assert_failure
  assert_output --partial "Unknown option"
}

@test "ai-lint: lints staged changes with AI" {
  echo "modified" > file.txt
  git add file.txt

  # Mock ai_call
  ai_call() {
    echo "No issues found."
  }
  export -f ai_call

  run command_ai_lint
  assert_success
  assert_output --partial "Linting 1 staged file"
  assert_output --partial "No issues found"
}

@test "ai-lint: strict mode fails on CRITICAL" {
  echo "modified" > file.txt
  git add file.txt

  _AIR_CONFIG["review.strict"]="true"

  ai_call() {
    echo "- [CRITICAL] file.txt:1 — SQL injection"
  }
  export -f ai_call

  run command_ai_lint
  assert_failure
  assert_output --partial "Critical issues found"
}

@test "ai-lint: non-strict passes with warnings" {
  echo "modified" > file.txt
  git add file.txt

  ai_call() {
    echo "- [WARNING] file.txt:1 — unused variable"
  }
  export -f ai_call

  run command_ai_lint
  assert_success
}
