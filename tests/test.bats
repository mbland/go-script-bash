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

@test "test: tab completion lists all tests/*.bats files" {
  run "$BASH" ./go test --complete
  assert_success "--list ${ALL_TESTS[*]}"
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

  local expected=(test aliases builtins builtins/doc-only-scripts)
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
  assert_failure '"foobar" does not match any test files.'
}

@test "test: produce an error if any test pattern fails to match" {
  run "$BASH" ./go test --list test 'foo*'
  assert_failure '"foo*" does not match any test files.'
}
