#! /usr/bin/env bats
#
# Tests for scripts/test.

load assertions

setup() {
  declare -g ALL_TESTS
  ALL_TESTS=(test/*.bats)
  ALL_TESTS=("${ALL_TESTS[@]#test/}")
  ALL_TESTS=("${ALL_TESTS[@]%.bats}")

  COLUMNS=1000
}

@test "test: tab completion lists all test/*.bats files" {
  run "$BASH" ./go test --complete
  assert_success "--list ${ALL_TESTS[*]}"
}

@test "test: no arguments lists test directory only" {
  run "$BASH" ./go test --list
  assert_success "test"
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

@test "test: produce an error if any test name fails to match" {
  run "$BASH" ./go test --list test foobar
  assert_failure '"foobar" does not match any test files.'
}

@test "test: produce an error if any test pattern fails to match" {
  run "$BASH" ./go test --list test 'foo*'
  assert_failure '"foo*" does not match any test files.'
}
