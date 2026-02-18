#!/usr/bin/env bats
# test/commands/doctor.bats — Tests for lib/commands/doctor.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset AIR_PROJECT_ROOT
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED _AIR_PLATFORM_LOADED
  unset _AIR_GLOBAL_CONFIG_LOADED _AIR_CONFIG_LOADED _AIR_DOTENV_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AI_REVIEW_PROVIDER AI_REVIEW_MODEL AI_REVIEW_API_KEY
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/platform.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/commands/doctor.sh"
  global_config_load
}

@test "doctor: output contains OS info" {
  run command_doctor
  assert_output --partial "OS:"
}

@test "doctor: output contains Bash version" {
  run command_doctor
  assert_output --partial "Bash:"
}

@test "doctor: detects project with .git" {
  mkdir -p "${TEST_TEMP_DIR}/project"
  mkdir "${TEST_TEMP_DIR}/project/.git"
  cd "${TEST_TEMP_DIR}/project"

  run command_doctor
  assert_output --partial "Project root:"
}

@test "doctor: warns when no project root" {
  cd "${TEST_TEMP_DIR}"

  run command_doctor
  assert_output --partial "No project root found"
}

@test "doctor: shows provider from global config" {
  global_config_set "provider" "claude"

  cd "${TEST_TEMP_DIR}"
  run command_doctor
  assert_output --partial "provider=claude"
}

@test "doctor: shows provider from env var" {
  export AI_REVIEW_PROVIDER=openai

  cd "${TEST_TEMP_DIR}"
  run command_doctor
  assert_output --partial "provider=openai"
  assert_output --partial "source: env"
  unset AI_REVIEW_PROVIDER
}

@test "doctor: exit code 0 when no issues" {
  cd "${TEST_TEMP_DIR}"
  run command_doctor
  # git and curl are available in CI and locally, bash is 4+
  assert_success
}

@test "doctor: shows model from cascade" {
  global_config_set "model" "sonnet"

  cd "${TEST_TEMP_DIR}"
  run command_doctor
  assert_output --partial "model=sonnet"
}
