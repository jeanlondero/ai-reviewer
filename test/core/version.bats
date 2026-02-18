#!/usr/bin/env bats
# test/core/version.bats — Tests for lib/core/version.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  unset _AIR_COLORS_LOADED _AIR_VERSION_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/version.sh"
}

@test "version: air_version returns semver format" {
  run air_version
  assert_success
  # Match semver pattern: X.Y.Z
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "version: air_version reads from VERSION file" {
  run air_version
  assert_success
  assert_output "0.1.0"
}

@test "version: air_print_version includes tool name" {
  run air_print_version
  assert_success
  assert_output --partial "ai-reviewer"
  assert_output --partial "0.1.0"
}

@test "version: air_version returns unknown when file missing" {
  local original_root="$AIR_ROOT"
  export AIR_ROOT="$TEST_TEMP_DIR"
  run air_version
  assert_output "unknown"
  export AIR_ROOT="$original_root"
}
