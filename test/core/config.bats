#!/usr/bin/env bats
# test/core/config.bats — Tests for lib/core/config.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED _AIR_CONFIG_LOADED
  unset _AIR_CONFIG
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
}

@test "config: loads flat key-value pairs" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
provider: claude
model: sonnet
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'provider')" == "claude" ]]
  [[ "$(config_get 'model')" == "sonnet" ]]
}

@test "config: handles quoted values" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
name: "my project"
path: '/usr/local/bin'
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'name')" == "my project" ]]
  [[ "$(config_get 'path')" == "/usr/local/bin" ]]
}

@test "config: returns default for missing keys" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
provider: claude
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'nonexistent' 'default_value')" == "default_value" ]]
}

@test "config: handles nested maps with dot notation" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
review:
  strict: true
  skills_dir: docs/skills
provider: claude
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'review.strict')" == "true" ]]
  [[ "$(config_get 'review.skills_dir')" == "docs/skills" ]]
  [[ "$(config_get 'provider')" == "claude" ]]
}

@test "config: returns failure for missing file" {
  run config_load "${TEST_TEMP_DIR}/nonexistent.yml"
  assert_failure
}

@test "config: ignores comments" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
# This is a comment
provider: claude
# Another comment
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'provider')" == "claude" ]]
}

@test "config: handles inline comments" {
  cat > "${TEST_TEMP_DIR}/config.yml" <<'EOF'
provider: claude # the default provider
EOF
  config_load "${TEST_TEMP_DIR}/config.yml"
  [[ "$(config_get 'provider')" == "claude" ]]
}
