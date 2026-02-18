#!/usr/bin/env bats
# test/core/colors.bats — Tests for lib/core/colors.sh

load '../test_helper'

setup() {
  # Call parent setup for temp dir
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR

  # Reset loaded flag so we can re-source
  unset _AIR_COLORS_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
}

@test "colors: info outputs to stderr" {
  run info "test message"
  assert_success
  assert_output --partial "test message"
  assert_output --partial "[info]"
}

@test "colors: error outputs to stderr" {
  run error "something failed"
  assert_success
  assert_output --partial "something failed"
  assert_output --partial "[error]"
}

@test "colors: warn outputs to stderr" {
  run warn "careful"
  assert_success
  assert_output --partial "careful"
  assert_output --partial "[warn]"
}

@test "colors: success outputs to stderr" {
  run success "it worked"
  assert_success
  assert_output --partial "it worked"
  assert_output --partial "[ok]"
}

@test "colors: die exits with code 1" {
  run die "fatal error"
  assert_failure
  assert_output --partial "fatal error"
}

@test "colors: NO_COLOR disables colors" {
  unset _AIR_COLORS_LOADED
  export NO_COLOR=1
  source "${AIR_ROOT}/lib/core/colors.sh"
  assert_equal "$RED" ""
  assert_equal "$GREEN" ""
  assert_equal "$BOLD" ""
  assert_equal "$RESET" ""
  unset NO_COLOR
}

@test "colors: header outputs formatted text" {
  run header "Test Header"
  assert_success
  assert_output --partial "Test Header"
}
