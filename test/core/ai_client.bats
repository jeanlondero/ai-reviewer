#!/usr/bin/env bats
# test/core/ai_client.bats — Tests for lib/core/ai_client.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_CONFIG_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_AI_CLIENT_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AI_REVIEW_PROVIDER AI_REVIEW_MODEL AI_REVIEW_API_KEY
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/core/ai_client.sh"
  global_config_load
}

@test "ai_client: fails without provider" {
  run ai_call "test prompt"
  assert_failure
  assert_output --partial "No AI provider"
}

@test "ai_client: fails without api_key" {
  global_config_set "provider" "claude"
  run ai_call "test prompt"
  assert_failure
  assert_output --partial "No API key"
}

@test "ai_client: fails with empty prompt" {
  run ai_call ""
  assert_failure
  assert_output --partial "prompt is required"
}

@test "ai_client: rejects unknown provider" {
  global_config_set "provider" "unknown_provider"
  global_config_set "api_key" "test-key"
  global_config_set "model" "some-model"
  run ai_call "test prompt"
  assert_failure
  assert_output --partial "Unknown AI provider"
}

@test "ai_client: json escape handles special characters" {
  run _ai_json_escape 'hello "world"'
  assert_success
  assert_output '"hello \"world\""'
}

@test "ai_client: json escape handles newlines" {
  run _ai_json_escape $'line1\nline2'
  assert_success
  assert_output '"line1\nline2"'
}

@test "ai_client: json escape handles backslashes" {
  run _ai_json_escape 'path\\to\\file'
  assert_success
  assert_output '"path\\\\to\\\\file"'
}

@test "ai_client: defaults model for claude provider" {
  global_config_set "provider" "claude"
  global_config_set "api_key" "test-key"
  # Mock curl to avoid real API calls
  curl() { printf '200'; return 0; }
  export -f curl
  # ai_call will fail at HTTP level, but we verify it doesn't fail at "no model" level
  run ai_call "test"
  # Should not contain "no model set" error
  refute_output --partial "no model set"
}

@test "ai_client: extract text claude with jq" {
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi
  local response='{"content":[{"type":"text","text":"Hello world"}]}'
  run _ai_extract_text_claude "$response"
  assert_success
  assert_output "Hello world"
}

@test "ai_client: extract text openai with jq" {
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi
  local response='{"choices":[{"message":{"content":"Hello world"}}]}'
  run _ai_extract_text_openai "$response"
  assert_success
  assert_output "Hello world"
}

@test "ai_client: extract text gemini with jq" {
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi
  local response='{"candidates":[{"content":{"parts":[{"text":"Hello world"}]}}]}'
  run _ai_extract_text_gemini "$response"
  assert_success
  assert_output "Hello world"
}

@test "ai_client: uses env vars for provider config" {
  export AI_REVIEW_PROVIDER=openai
  export AI_REVIEW_API_KEY=test-key-123
  export AI_REVIEW_MODEL=gpt-4

  # Will fail at network level but should get past config validation
  run ai_call "test prompt"
  refute_output --partial "No AI provider"
  refute_output --partial "No API key"

  unset AI_REVIEW_PROVIDER AI_REVIEW_API_KEY AI_REVIEW_MODEL
}
