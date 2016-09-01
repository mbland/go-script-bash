#! /usr/bin/env bats
#
# Tests for scripts/test.

load environment
load assertions

ALL_TESTS=($("$BASH" './go' 'glob' '--compact' '--ignore' 'bats/*' \
  'tests' '.bats'))

_fill_expected_completions() {
  local pattern="$1"
  local entry

  for entry in $pattern; do
    if [[ -d "$entry" ]]; then
      if [[ -f "$entry.bats" ]]; then
        expected+=("$entry")
      fi

      local contents=($entry/*.bats)
      if [[ "${contents[0]}" != "$entry/*.bats" ]]; then
        expected+=("$entry/")
      fi
    elif [[ -f "$entry" && "${entry##*.}" = "bats" \
      && ! -d "${entry%.bats}" ]]; then
      expected+=("${entry%.bats}")
    fi
  done
  expected=("${expected[@]#tests/}")
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

@test "test: no arguments after --list lists all tests" {
  run "$BASH" ./go test --list
  local IFS=$'\n'
  assert_success "${ALL_TESTS[*]}"
}

@test "test: glob after --list lists all tests" {
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
