#!/usr/bin/env bash
# test/test_helper.bash — Common test setup for bats.

# Resolve AIR_ROOT from this file's location
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AIR_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# Load bats helpers
load "${TEST_DIR}/bats-support/load"
load "${TEST_DIR}/bats-assert/load"

# Create a temp directory for each test
setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
}

teardown() {
  if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}
