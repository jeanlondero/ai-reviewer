#!/usr/bin/env bats
# test/core/utils.bats — Tests for lib/core/utils.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  unset AIR_PROJECT_ROOT
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
}

@test "air_find_project_root: finds .git directory" {
  mkdir -p "${TEST_TEMP_DIR}/project/subdir"
  mkdir "${TEST_TEMP_DIR}/project/.git"
  cd "${TEST_TEMP_DIR}/project/subdir"

  air_find_project_root
  [[ "$AIR_PROJECT_ROOT" == "${TEST_TEMP_DIR}/project" ]]
}

@test "air_find_project_root: finds .ai-reviewer.yml" {
  mkdir -p "${TEST_TEMP_DIR}/project/subdir"
  touch "${TEST_TEMP_DIR}/project/.ai-reviewer.yml"
  cd "${TEST_TEMP_DIR}/project/subdir"

  air_find_project_root
  [[ "$AIR_PROJECT_ROOT" == "${TEST_TEMP_DIR}/project" ]]
}

@test "air_find_project_root: prefers nearest root going up" {
  mkdir -p "${TEST_TEMP_DIR}/outer/.git"
  mkdir -p "${TEST_TEMP_DIR}/outer/inner"
  touch "${TEST_TEMP_DIR}/outer/inner/.ai-reviewer.yml"
  cd "${TEST_TEMP_DIR}/outer/inner"

  air_find_project_root
  [[ "$AIR_PROJECT_ROOT" == "${TEST_TEMP_DIR}/outer/inner" ]]
}

@test "air_find_project_root: fails when no root found" {
  cd "${TEST_TEMP_DIR}"

  run air_find_project_root
  assert_failure
}

@test "air_find_project_root: works from project root itself" {
  mkdir "${TEST_TEMP_DIR}/.git"
  cd "${TEST_TEMP_DIR}"

  air_find_project_root
  [[ "$AIR_PROJECT_ROOT" == "${TEST_TEMP_DIR}" ]]
}

@test "air_find_project_root: sets AIR_PROJECT_ROOT variable" {
  mkdir "${TEST_TEMP_DIR}/.git"
  cd "${TEST_TEMP_DIR}"

  air_find_project_root
  [[ -n "$AIR_PROJECT_ROOT" ]]
  [[ "$AIR_PROJECT_ROOT" == "${TEST_TEMP_DIR}" ]]
}
