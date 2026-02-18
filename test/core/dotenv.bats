#!/usr/bin/env bats
# test/core/dotenv.bats — Tests for lib/core/dotenv.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  unset _AIR_COLORS_LOADED _AIR_UTILS_LOADED _AIR_DOTENV_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/dotenv.sh"

  # Clean test env vars
  unset TEST_KEY TEST_QUOTED TEST_SINGLE TEST_INLINE TEST_DEV_KEY TEST_OVERRIDE
}

@test "dotenv: loads key=value pairs" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_KEY=hello
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_KEY" "hello"
}

@test "dotenv: handles double-quoted values" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_QUOTED="hello world"
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_QUOTED" "hello world"
}

@test "dotenv: handles single-quoted values" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_SINGLE='hello world'
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_SINGLE" "hello world"
}

@test "dotenv: removes inline comments" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_INLINE=value # this is a comment
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_INLINE" "value"
}

@test "dotenv: does not override existing env vars" {
  export TEST_OVERRIDE="original"
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_OVERRIDE=new_value
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_OVERRIDE" "original"
  unset TEST_OVERRIDE
}

@test "dotenv: loads .env.development" {
  cat > "${TEST_TEMP_DIR}/.env.development" <<'EOF'
TEST_DEV_KEY=dev_value
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_DEV_KEY" "dev_value"
}

@test "dotenv: .env takes precedence over .env.development" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
TEST_KEY=from_env
EOF
  cat > "${TEST_TEMP_DIR}/.env.development" <<'EOF'
TEST_KEY=from_dev
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_KEY" "from_env"
}

@test "dotenv: skips comments and empty lines" {
  cat > "${TEST_TEMP_DIR}/.env" <<'EOF'
# This is a comment

TEST_KEY=value

# Another comment
EOF
  dotenv_load "$TEST_TEMP_DIR"
  assert_equal "$TEST_KEY" "value"
}

@test "dotenv: handles missing files gracefully" {
  run dotenv_load "$TEST_TEMP_DIR"
  assert_success
}
