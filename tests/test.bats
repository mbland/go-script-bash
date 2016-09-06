#! /usr/bin/env bats
#
# Tests for scripts/test.

load environment
load assertions

@test "$SUITE: tab complete flags" {
  run ./go test --complete 0 '-'
  local expected=('--edit' '--list')
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: tab complete flags, first-level tests and directories" {
  local expected=('--edit' '--list')
  expected+=($('./go' 'glob' '--complete' '5' \
    '--trim' '--ignore' 'bats/*' 'tests' '.bats'))
  [[ "${#expected[@]}" -ne 1 ]]

  run ./go test --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: tab completion matches test file and matching directory" {
  expected=('core' 'core/')
  run ./go test --complete 0 'core'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

_trim_expected() {
  expected=("${expected[@]#tests/}")
  expected=("${expected[@]%.bats}")
}

@test "$SUITE: tab completion lists second-level tests and directories" {
  local expected=(tests/core/*.bats)
  _trim_expected

  run ./go test --complete 0 'core/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: no arguments after --list lists all tests" {
  local expected=(
    $('./go' 'glob' '--trim' '--ignore' 'bats/*' 'tests' '.bats'))
  [[ "${#expected[@]}" -ne 0 ]]

  run ./go test --list
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list specific files and directories" {
  run ./go test --list test aliases 'builtins*'

  local expected=(test aliases builtins tests/builtins/*)
  _trim_expected

  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: produce an error if any test pattern fails to match" {
  run ./go test --list test 'foo*'
  assert_failure '"foo*" does not match any .bats files in tests.'
}
