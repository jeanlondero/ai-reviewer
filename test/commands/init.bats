#!/usr/bin/env bats
# test/commands/init.bats — Tests for lib/commands/init.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_PLATFORM_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_CONFIG_LOADED _AIR_UTILS_LOADED _AIR_INTERACTIVE_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AI_REVIEW_PROVIDER AI_REVIEW_MODEL AI_REVIEW_API_KEY
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/platform.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/commands/init.sh"
  global_config_load
}

@test "init: creates .ai-reviewer.yml" {
  cd "${TEST_TEMP_DIR}"
  run command_init
  assert_success
  assert_output --partial "Created .ai-reviewer.yml"
  [[ -f "${TEST_TEMP_DIR}/.ai-reviewer.yml" ]]
}

@test "init: generated config has expected content" {
  cd "${TEST_TEMP_DIR}"
  command_init
  run cat "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  assert_output --partial "provider: claude"
  assert_output --partial "model: claude-sonnet-4-20250514"
  assert_output --partial "commit_lint:"
  assert_output --partial "types:"
}

@test "init: refuses if .ai-reviewer.yml exists" {
  cd "${TEST_TEMP_DIR}"
  touch "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  run command_init
  assert_failure
  assert_output --partial "already exists"
}

@test "init: --force overwrites existing config" {
  cd "${TEST_TEMP_DIR}"
  echo "old: content" > "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  run command_init --force
  assert_success
  assert_output --partial "Created .ai-reviewer.yml"
  run cat "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  assert_output --partial "provider: claude"
}

@test "init: shows next steps" {
  cd "${TEST_TEMP_DIR}"
  run command_init
  assert_success
  assert_output --partial "Next steps"
  assert_output --partial "air config init"
  assert_output --partial "air doctor"
}

@test "init: --help shows usage" {
  run command_init --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "--force"
}

@test "init: uses configured provider in generated yml" {
  global_config_set "provider" "openai"
  global_config_set "model" "gpt-4o"
  cd "${TEST_TEMP_DIR}"
  run command_init
  assert_success
  run cat "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  assert_output --partial "provider: openai"
  assert_output --partial "model: gpt-4o"
}

@test "init: defaults provider model when only provider configured" {
  global_config_set "provider" "gemini"
  cd "${TEST_TEMP_DIR}"
  run command_init
  assert_success
  run cat "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  assert_output --partial "provider: gemini"
  assert_output --partial "model: gemini-2.0-flash"
}
