#!/usr/bin/env bats
# test/core/global_config.bats — Tests for lib/core/global_config.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/config"
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_GLOBAL_CONFIG
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
}

@test "global_config: config_dir returns path without creating" {
  run _air_global_config_dir
  assert_success
  assert_output "${TEST_TEMP_DIR}/config"
  [[ ! -d "${TEST_TEMP_DIR}/config" ]]
}

@test "global_config: ensure_config_dir creates dir with correct permissions" {
  run _air_global_ensure_config_dir
  assert_success
  [[ -d "${TEST_TEMP_DIR}/config" ]]
  local perms
  perms="$(stat -f '%Lp' "${TEST_TEMP_DIR}/config" 2>/dev/null || stat -c '%a' "${TEST_TEMP_DIR}/config" 2>/dev/null)"
  assert_equal "$perms" "700"
}

@test "global_config: set and get regular key" {
  global_config_set "provider" "claude"
  assert_equal "$(global_config_get 'provider')" "claude"
}

@test "global_config: regular key stored in config file" {
  global_config_set "provider" "claude"
  local config_file
  config_file="$(_air_global_config_file)"
  [[ -f "$config_file" ]]
  run cat "$config_file"
  assert_output --partial "provider=claude"
}

@test "global_config: secret key stored in credentials file" {
  global_config_set "api_key" "sk-ant-test123"
  local creds_file
  creds_file="$(_air_global_credentials_file)"
  [[ -f "$creds_file" ]]
  run cat "$creds_file"
  assert_output --partial "api_key=sk-ant-test123"
}

@test "global_config: credentials file has chmod 600" {
  global_config_set "api_key" "sk-ant-test123"
  local creds_file perms
  creds_file="$(_air_global_credentials_file)"
  perms="$(stat -f '%Lp' "$creds_file" 2>/dev/null || stat -c '%a' "$creds_file" 2>/dev/null)"
  assert_equal "$perms" "600"
}

@test "global_config: config file has chmod 644" {
  global_config_set "provider" "claude"
  local config_file perms
  config_file="$(_air_global_config_file)"
  perms="$(stat -f '%Lp' "$config_file" 2>/dev/null || stat -c '%a' "$config_file" 2>/dev/null)"
  assert_equal "$perms" "644"
}

@test "global_config: unset removes key" {
  global_config_set "provider" "claude"
  global_config_unset "provider"
  assert_equal "$(global_config_get 'provider')" ""
}

@test "global_config: unset returns failure for missing key" {
  run global_config_unset "nonexistent"
  assert_failure
}

@test "global_config: load reads both files" {
  global_config_set "provider" "openai"
  global_config_set "api_key" "sk-test"

  # Reset and reload
  unset _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_GLOBAL_CONFIG
  source "${AIR_ROOT}/lib/core/global_config.sh"
  global_config_load

  assert_equal "$(global_config_get 'provider')" "openai"
  assert_equal "$(global_config_get 'api_key')" "sk-test"
}

@test "global_config: handles quoted values in files" {
  _air_global_ensure_config_dir >/dev/null
  local config_file
  config_file="$(_air_global_config_file)"
  printf 'provider="claude"\nmodel='"'"'sonnet'"'"'\n' > "$config_file"

  global_config_load
  assert_equal "$(global_config_get 'provider')" "claude"
  assert_equal "$(global_config_get 'model')" "sonnet"
}

@test "global_config: skips comments in files" {
  _air_global_ensure_config_dir >/dev/null
  local config_file
  config_file="$(_air_global_config_file)"
  cat > "$config_file" <<'EOF'
# This is a comment
provider=claude
# Another comment
model=sonnet
EOF
  global_config_load
  assert_equal "$(global_config_get 'provider')" "claude"
  assert_equal "$(global_config_get 'model')" "sonnet"
}

@test "global_config: list masks secret values" {
  global_config_set "provider" "claude"
  global_config_set "api_key" "sk-ant-abcd1234"

  run global_config_list
  assert_success
  assert_output --partial "provider=claude"
  assert_output --partial "api_key=****1234"
  refute_output --partial "sk-ant-abcd1234"
}

@test "global_config: set overwrites existing key" {
  global_config_set "provider" "claude"
  global_config_set "provider" "openai"
  assert_equal "$(global_config_get 'provider')" "openai"

  # Verify file doesn't have duplicate entries
  local config_file count
  config_file="$(_air_global_config_file)"
  count="$(grep -c 'provider=' "$config_file")"
  assert_equal "$count" "1"
}
