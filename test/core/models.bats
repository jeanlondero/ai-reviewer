#!/usr/bin/env bats
# test/core/models.bats — Tests for lib/core/models.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_MODELS_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/models.sh"
}

@test "models: lists claude models" {
  run models_list_for_provider claude
  assert_success
  assert_output --partial "claude-sonnet-4-20250514"
  assert_output --partial "claude-opus-4-20250514"
  assert_output --partial "claude-haiku-4-5-20251001"
}

@test "models: lists openai models" {
  run models_list_for_provider openai
  assert_success
  assert_output --partial "gpt-4o"
  assert_output --partial "gpt-4o-mini"
  assert_output --partial "o1"
  assert_output --partial "o3-mini"
}

@test "models: lists gemini models" {
  run models_list_for_provider gemini
  assert_success
  assert_output --partial "gemini-2.0-flash"
  assert_output --partial "gemini-2.5-pro"
  assert_output --partial "gemini-2.5-flash"
}

@test "models: get default for each provider" {
  run models_get_default claude
  assert_success
  assert_output "claude-sonnet-4-20250514"

  run models_get_default openai
  assert_success
  assert_output "gpt-4o"

  run models_get_default gemini
  assert_success
  assert_output "gemini-2.0-flash"
}

@test "models: get description for known model" {
  run models_get_description claude "claude-sonnet-4-20250514"
  assert_success
  assert_output "Fast, balanced"

  run models_get_description openai "gpt-4o"
  assert_success
  assert_output "Flagship multimodal"
}

@test "models: get description returns 1 for unknown model" {
  run models_get_description claude "nonexistent-model"
  assert_failure
}

@test "models: display list includes recommended marker" {
  run models_get_display_list claude
  assert_success
  assert_output --partial "recommended"
  assert_output --partial "claude-sonnet-4-20250514"
}

@test "models: returns failure for unknown provider" {
  run models_list_for_provider unknown_provider
  assert_failure
}

@test "models: fetch_dynamic returns 1 for claude" {
  run models_fetch_dynamic claude "fake-key"
  assert_failure
}
