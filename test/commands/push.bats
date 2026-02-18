#!/usr/bin/env bats
# test/commands/push.bats — Tests for lib/commands/push.sh

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
  source "${AIR_ROOT}/lib/commands/commit-lint.sh"
  source "${AIR_ROOT}/lib/commands/ai-review.sh"
  source "${AIR_ROOT}/lib/commands/push.sh"
  global_config_load
}

_setup_git_repo_with_remote() {
  # Create a bare "remote" repo
  local remote_dir="${TEST_TEMP_DIR}/remote.git"
  git init -q --bare "$remote_dir"

  # Create the local working repo
  local repo_dir="${TEST_TEMP_DIR}/repo"
  mkdir -p "$repo_dir"
  cd "$repo_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "feat: initial commit"
  git remote add origin "$remote_dir"
  git push -q -u origin main 2>/dev/null || git push -q -u origin master 2>/dev/null || true
}

@test "push: fails if not in a git repo" {
  cd /tmp
  run command_push
  assert_failure
  assert_output --partial "Not in a git repository"
}

@test "push: fails if no remote configured" {
  cd "${TEST_TEMP_DIR}"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -q -m "feat: test"
  run command_push
  assert_failure
  assert_output --partial "No remote"
}

@test "push: warns when no commits to push" {
  _setup_git_repo_with_remote
  run command_push
  assert_success
  assert_output --partial "No commits to push"
}

@test "push: validates commit messages" {
  _setup_git_repo_with_remote
  echo "change" > file.txt
  git add file.txt
  git commit -q -m "feat: add a new feature"

  run command_push --validate-only
  assert_success
  assert_output --partial "All commit messages are valid"
  assert_output --partial "Validation passed"
}

@test "push: fails validation on bad commit messages" {
  _setup_git_repo_with_remote
  echo "change" > file.txt
  git add file.txt
  git commit -q -m "bad commit message" --no-verify 2>/dev/null || git commit -q -m "bad commit message"

  run command_push --validate-only
  assert_failure
  assert_output --partial "failed validation"
}

@test "push: --validate-only does not push" {
  _setup_git_repo_with_remote
  echo "change" > file.txt
  git add file.txt
  git commit -q -m "feat: a valid change"

  run command_push --validate-only
  assert_success
  assert_output --partial "validate-only"
  refute_output --partial "Push complete"
}

@test "push: --help shows usage" {
  run command_push --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "--validate-only"
  assert_output --partial "--skip-review"
}

@test "push: actually pushes valid commits" {
  _setup_git_repo_with_remote
  echo "change" > file.txt
  git add file.txt
  git commit -q -m "feat: add feature"

  run command_push
  assert_success
  assert_output --partial "Push complete"
}
