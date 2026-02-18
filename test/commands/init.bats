#!/usr/bin/env bats
# test/commands/init.bats — Tests for lib/commands/init.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_PLATFORM_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/platform.sh"
  source "${AIR_ROOT}/lib/commands/init.sh"
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
