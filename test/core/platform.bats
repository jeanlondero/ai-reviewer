#!/usr/bin/env bats
# test/core/platform.bats — Tests for lib/core/platform.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  unset _AIR_COLORS_LOADED _AIR_PLATFORM_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/platform.sh"
}

@test "platform: detect_os returns known value" {
  run detect_os
  assert_success
  # Should be one of: macos, linux, windows, unknown
  assert [ -n "$output" ]
}

@test "platform: detect_os returns macos on macOS" {
  if [[ "$(uname -s)" != Darwin* ]]; then
    skip "Not on macOS"
  fi
  run detect_os
  assert_output "macos"
}

@test "platform: check_bash_version succeeds on bash 4+" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "Bash version too old"
  fi
  run check_bash_version
  assert_success
}

@test "platform: check_dependency finds bash" {
  run check_dependency bash
  assert_success
}

@test "platform: check_dependency fails for nonexistent" {
  run check_dependency nonexistent_tool_xyz_12345
  assert_failure
}

@test "platform: check_all_deps succeeds with existing tools" {
  run check_all_deps bash cat
  assert_success
}

@test "platform: check_all_deps fails with missing tool" {
  run check_all_deps bash nonexistent_tool_xyz_12345
  assert_failure
  assert_output --partial "Missing required dependencies"
}
