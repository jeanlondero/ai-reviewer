#!/usr/bin/env bats
# test/commands/update.bats — Tests for lib/commands/update.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_VERSION_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/version.sh"
  source "${AIR_ROOT}/lib/commands/update.sh"
}

@test "update: fails if AIR_ROOT is not a git repo" {
  local saved_root="$AIR_ROOT"
  export AIR_ROOT="${TEST_TEMP_DIR}"
  mkdir -p "${TEST_TEMP_DIR}"
  echo "0.1.0" > "${TEST_TEMP_DIR}/VERSION"
  run command_update
  assert_failure
  assert_output --partial "Not a git installation"
  export AIR_ROOT="$saved_root"
}

@test "update: shows current version" {
  # Create a fake git repo to pass the .git check
  local fake_root="${TEST_TEMP_DIR}/air"
  mkdir -p "${fake_root}/.git"
  echo "1.0.0" > "${fake_root}/VERSION"
  local saved_root="$AIR_ROOT"
  export AIR_ROOT="$fake_root"

  # git fetch will fail (no remote), but we test the version display path
  run command_update
  # It will fail at fetch, but should show version first
  assert_output --partial "Current version: 1.0.0"
  export AIR_ROOT="$saved_root"
}

@test "update: --help shows usage" {
  run command_update --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "Self-update"
}

@test "update: rejects unknown flags" {
  run command_update --invalid
  assert_failure
  assert_output --partial "Unknown option"
}

@test "update: header is shown" {
  local saved_root="$AIR_ROOT"
  export AIR_ROOT="${TEST_TEMP_DIR}"
  run command_update
  assert_output --partial "ai-reviewer update"
  export AIR_ROOT="$saved_root"
}
