#! /usr/bin/env bats
#
# Tests for scripts/test.

setup() {
  declare -g ALL_TESTS=(test/*.bats)
  ALL_TESTS=("${ALL_TESTS[@]#test/}")
  ALL_TESTS=("${ALL_TESTS[@]%.bats}")

  COLUMNS=1000
}

@test "test: tab completion lists all test/*.bats files" {
  run "$BASH" ./go test --complete
  [[ "$status" -eq '0' ]]
  echo "EXPECT '--list ${ALL_TESTS[@]}" >&2
  echo "OUTPUT '$output'" >&2
  [[ "$output" = "--list ${ALL_TESTS[@]}" ]]
}

@test "test: no arguments lists test directory only" {
  run "$BASH" ./go test --list
  [[ "$status" -eq '0' ]]
  [[ "$output" = "test" ]]
}

@test "test: glob lists all tests" {
  run "$BASH" ./go test --list '*'
  [[ "$status" -eq '0' ]]
  local IFS=$'\n'
  echo "EXPECT '${ALL_TESTS[*]}'" >&2
  echo "OUTPUT '$output'" >&2
  [[ "$output" = "${ALL_TESTS[*]}" ]]
}

@test "test: single test name lists only that name" {
  run "$BASH" ./go test --list test
  [[ "$status" -eq '0' ]]
  [[ "$output" = 'test' ]]
}

@test "test: produce an error if any test name fails to match" {
  run "$BASH" ./go test --list test foobar
  [[ "$status" -eq '1' ]]
  [[ "$output" = '"foobar" does not match any test files.' ]]
}

@test "test: produce an error if any test pattern fails to match" {
  run "$BASH" ./go test --list test 'foo*'
  [[ "$status" -eq '1' ]]
  [[ "$output" = '"foo*" does not match any test files.' ]]
}
