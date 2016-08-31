#! /usr/bin/env bats
#
# Tests for scripts/test.

load environment
load assertions

ALL_TESTS=()

_setup_helper() {
  local glob_pattern="$1"
  local test_path

  for test_path in $glob_pattern.bats; do
    ALL_TESTS+=("$test_path")

    if [[ -d "${test_path%.bats}" ]]; then
      _setup_helper "${test_path%.bats}/*"
    fi
  done
}

setup() {
  _setup_helper 'tests/*'
  ALL_TESTS=("${ALL_TESTS[@]#tests/}")
  ALL_TESTS=("${ALL_TESTS[@]%.bats}")
}

_fill_expected_completions() {
  local pattern="$1"
  local test_name

  for test_name in $pattern.bats; do
    test_name="${test_name%.bats}"
    expected+=("${test_name#tests/}")

    if [[ -d "$test_name" ]]; then
      expected+=("${test_name#tests/}/")
    fi
  done
}

@test "test: tab complete flags" {
  run "$BASH" ./go test --complete 0 '-'
  assert_success "--list"
}

@test "test: tab completion lists first-level tests and directories" {
  local expected=('--list')
  _fill_expected_completions 'tests/*'

  run "$BASH" ./go test --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: tab completion matches test file and matching directory" {
  expected=('core' 'core/')
  run "$BASH" ./go test --complete 0 'core'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: tab completion lists second-level tests and directories" {
  local expected=()
  _fill_expected_completions 'tests/core/*'

  run "$BASH" ./go test --complete 0 'core/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: no arguments lists all tests" {
  run "$BASH" ./go test --list
  local IFS=$'\n'
  assert_success "${ALL_TESTS[*]}"
}

@test "test: glob lists all tests" {
  run "$BASH" ./go test --list '*'
  local IFS=$'\n'
  assert_success "${ALL_TESTS[*]}"
}

@test "test: single test name lists only that name" {
  run "$BASH" ./go test --list test
  assert_success 'test'
}

@test "test: multiple test names list multiple names" {
  run "$BASH" ./go test --list test aliases argv

  local expected=(test aliases argv)
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: a pattern matching a directory name returns its files" {
  run "$BASH" ./go test --list test aliases 'builtins*'

  local expected=(test aliases builtins)
  _fill_expected_completions 'tests/builtins/*'

  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: a pattern matching a file and directory returns the file only" {
  run "$BASH" ./go test --list test aliases builtins

  local expected=(test aliases builtins)
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "test: produce an error if any test name fails to match" {
  run "$BASH" ./go test --list test foobar
  assert_failure '"foobar" does not match any .bats files in tests.'
}

@test "test: produce an error if any test pattern fails to match" {
  run "$BASH" ./go test --list test 'foo*'
  assert_failure '"foo*" does not match any .bats files in tests.'
}
