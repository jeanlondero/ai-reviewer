#!/usr/bin/env bats
# test/commands/config.bats — Tests for lib/commands/config.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/config"
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED _AIR_CONFIG_LOADED
  unset _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/commands/config.sh"
  global_config_load
}

@test "config command: set and get a value" {
  command_config set provider claude

  run command_config get provider
  assert_success
  assert_output --partial "claude"
}

@test "config command: get returns not set for missing key" {
  run command_config get nonexistent
  assert_failure
  assert_output --partial "not set"
}

@test "config command: unset removes a value" {
  command_config set provider claude
  run command_config unset provider
  assert_success
  assert_output --partial "Unset"
}

@test "config command: unset returns warning for missing key" {
  run command_config unset nonexistent
  assert_failure
  assert_output --partial "not found"
}

@test "config command: list shows all values" {
  command_config set provider claude
  command_config set model sonnet
  run command_config list
  assert_success
  assert_output --partial "provider=claude"
  assert_output --partial "model=sonnet"
}

@test "config command: list masks secrets" {
  command_config set api_key sk-ant-test1234
  run command_config list
  assert_success
  assert_output --partial "api_key=****1234"
  refute_output --partial "sk-ant-test1234"
}

@test "config command: cascade prefers env var" {
  command_config set provider claude
  export AI_REVIEW_PROVIDER=openai
  run command_config get provider
  assert_success
  assert_output --partial "openai"
  assert_output --partial "source: env"
  unset AI_REVIEW_PROVIDER
}

@test "config command: cascade falls back to global" {
  command_config set provider claude
  run command_config get provider
  assert_success
  assert_output --partial "claude"
  assert_output --partial "source: global"
}

@test "config command: set requires key and value" {
  run command_config set
  assert_failure
  assert_output --partial "Usage"
}

@test "config command: unknown subcommand fails" {
  run command_config foobar
  assert_failure
  assert_output --partial "Unknown config subcommand"
}

@test "config command: path returns config directory" {
  run command_config path
  assert_success
  assert_output --partial "${TEST_TEMP_DIR}/config"
}
