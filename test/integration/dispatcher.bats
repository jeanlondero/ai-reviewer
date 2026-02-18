#!/usr/bin/env bats
# test/integration/dispatcher.bats — End-to-end tests for bin/ai-reviewer

load '../test_helper'

AIR_BIN="${AIR_ROOT}/bin/ai-reviewer"

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
}

@test "dispatcher: --version prints version" {
  run "$AIR_BIN" --version
  assert_success
  assert_output --partial "ai-reviewer"
}

@test "dispatcher: -v prints version" {
  run "$AIR_BIN" -v
  assert_success
  assert_output --partial "ai-reviewer"
}

@test "dispatcher: --help shows usage" {
  run "$AIR_BIN" --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "COMMANDS"
}

@test "dispatcher: -h shows usage" {
  run "$AIR_BIN" -h
  assert_success
  assert_output --partial "USAGE"
}

@test "dispatcher: help command shows usage" {
  run "$AIR_BIN" help
  assert_success
  assert_output --partial "COMMANDS"
}

@test "dispatcher: unknown command exits 1" {
  run "$AIR_BIN" nonexistent-command
  assert_failure
  assert_output --partial "Unknown command"
}

@test "dispatcher: --no-color suppresses ANSI codes" {
  run "$AIR_BIN" --no-color --help
  assert_success
  # Should not contain ANSI escape sequences
  refute_output --partial $'\033['
}

@test "dispatcher: routes to doctor" {
  cd "${TEST_TEMP_DIR}"
  run "$AIR_BIN" doctor
  assert_output --partial "ai-reviewer doctor"
  assert_output --partial "OS:"
}
