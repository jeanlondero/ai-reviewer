#!/usr/bin/env bats
# test/core/interactive.bats — Tests for lib/core/interactive.sh

load '../test_helper'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export NO_COLOR=1
  unset _AIR_COLORS_LOADED _AIR_INTERACTIVE_LOADED
  source "${AIR_ROOT}/lib/core/colors.sh"
  source "${AIR_ROOT}/lib/core/interactive.sh"
}

@test "interactive: air_is_interactive returns 1 in pipe" {
  run air_is_interactive
  assert_failure
}

@test "interactive: air_menu returns 1 when not interactive" {
  local result=""
  run air_menu "Pick one" result "a:Alpha" "b:Beta"
  assert_failure
  assert_equal "$status" 1
}

@test "interactive: air_menu selects option via redirect" {
  _test_menu_select() {
    air_is_interactive() { return 0; }
    local result=""
    air_menu "Pick one" result "alpha:Alpha" "beta:Beta" <<< "2"
    printf 'SELECTED=%s' "$result"
  }
  run _test_menu_select
  assert_success
  assert_output --partial "SELECTED=beta"
}

@test "interactive: air_menu defaults to option 1" {
  _test_menu_default() {
    air_is_interactive() { return 0; }
    local result=""
    air_menu "Pick one" result "alpha:Alpha" "beta:Beta" <<< ""
    printf 'SELECTED=%s' "$result"
  }
  run _test_menu_default
  assert_success
  assert_output --partial "SELECTED=alpha"
}

@test "interactive: air_confirm uses default when not interactive" {
  run air_confirm "Continue?" "Y"
  assert_success

  run air_confirm "Continue?" "N"
  assert_failure
}

@test "interactive: air_input uses default when not interactive" {
  _test_input_default() {
    local result=""
    air_input "Name" result "fallback"
    printf '%s' "$result"
  }
  run _test_input_default
  assert_success
  assert_output "fallback"
}

@test "interactive: air_input returns 1 when not interactive and no default" {
  _test_input_no_default() {
    local result=""
    air_input "Name" result
  }
  run _test_input_no_default
  assert_failure
}

@test "interactive: air_secret returns 1 when not interactive" {
  _test_secret() {
    local result=""
    air_secret "API key" result
  }
  run _test_secret
  assert_failure
}

@test "interactive: air_status_label configured" {
  run air_status_label "configured"
  assert_success
  assert_output --partial "configured"
}

@test "interactive: air_status_label missing" {
  run air_status_label "missing"
  assert_success
  assert_output --partial "not configured"
}

@test "interactive: air_status_label partial" {
  run air_status_label "partial"
  assert_success
  assert_output --partial "partial"
}

@test "interactive: air_spinner_start in non-TTY prints message" {
  run air_spinner_start "Loading"
  assert_success
  assert_output --partial "Loading"
}
