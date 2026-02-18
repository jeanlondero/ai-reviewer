#!/usr/bin/env bats
# test/commands/commit-lint.bats — Tests for lib/commands/commit-lint.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export AIR_CONFIG_DIR="${TEST_TEMP_DIR}/globalcfg"
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_CONFIG_LOADED _AIR_GLOBAL_CONFIG_LOADED
  unset _AIR_GLOBAL_CONFIG _AIR_CONFIG
  unset AIR_PROJECT_ROOT
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/utils.sh"
  source "${AIR_ROOT}/lib/core/global_config.sh"
  source "${AIR_ROOT}/lib/core/config.sh"
  source "${AIR_ROOT}/lib/commands/commit-lint.sh"
  global_config_load
}

@test "commit-lint: valid conventional commit passes" {
  run command_commit_lint "feat: add user auth"
  assert_success
  assert_output --partial "valid"
}

@test "commit-lint: valid commit with scope passes" {
  run command_commit_lint "fix(api): handle null response"
  assert_success
  assert_output --partial "valid"
}

@test "commit-lint: valid commit with breaking change marker" {
  run command_commit_lint "feat!: drop support for node 14"
  assert_success
}

@test "commit-lint: rejects message without type" {
  run command_commit_lint "just a bad message"
  assert_failure
  assert_output --partial "Invalid format"
}

@test "commit-lint: rejects unknown type" {
  run command_commit_lint "yolo: something random"
  assert_failure
  assert_output --partial "Unknown type"
}

@test "commit-lint: rejects uppercase description" {
  run command_commit_lint "feat: Add something"
  assert_failure
  assert_output --partial "lowercase"
}

@test "commit-lint: rejects trailing period" {
  run command_commit_lint "feat: add something."
  assert_failure
  assert_output --partial "period"
}

@test "commit-lint: rejects too-long subject line" {
  local long_msg="feat: $(printf '%0.sa' {1..80})"
  run command_commit_lint "$long_msg"
  assert_failure
  assert_output --partial "too long"
}

@test "commit-lint: reads message from file" {
  echo "docs: update readme" > "${TEST_TEMP_DIR}/msg.txt"
  run command_commit_lint "${TEST_TEMP_DIR}/msg.txt"
  assert_success
  assert_output --partial "valid"
}

@test "commit-lint: reads from stdin" {
  run bash -c "echo 'test: add unit tests' | source '${AIR_ROOT}/lib/core/colors.sh' && source '${AIR_ROOT}/lib/core/utils.sh' && source '${AIR_ROOT}/lib/core/global_config.sh' && source '${AIR_ROOT}/lib/core/config.sh' && source '${AIR_ROOT}/lib/commands/commit-lint.sh' && global_config_load && command_commit_lint"
  assert_success
}

@test "commit-lint: errors when no message provided" {
  cd /tmp
  run command_commit_lint ""
  assert_failure
  assert_output --partial "No commit message"
}

@test "commit-lint: respects custom types from config" {
  cat > "${TEST_TEMP_DIR}/.ai-reviewer.yml" <<'EOF'
commit_lint:
  types: [feat, fix, custom]
EOF
  config_load "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  run command_commit_lint "custom: my custom type"
  assert_success
}

@test "commit-lint: respects custom max_line_length" {
  cat > "${TEST_TEMP_DIR}/.ai-reviewer.yml" <<'EOF'
commit_lint:
  max_line_length: 50
EOF
  config_load "${TEST_TEMP_DIR}/.ai-reviewer.yml"
  run command_commit_lint "feat: this is a somewhat long message that exceeds fifty chars"
  assert_failure
  assert_output --partial "too long"
}

@test "commit-lint: --help shows usage" {
  run command_commit_lint --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "FORMAT"
}
