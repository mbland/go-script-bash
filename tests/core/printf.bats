#! /usr/bin/env bats

load ../environment

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: wrap text according to COLUMNS" {
  create_test_go_script '@go.printf "%s" "1234567890 1234567890 1234567890"'
  COLUMNS=25 run "$TEST_GO_SCRIPT"
  assert_success $'1234567890 1234567890\n1234567890'
}

@test "$SUITE: escape percent signs if only one argument" {
  local test_text='This contains a suffix deletion: ${FOO%/*}'
  create_test_go_script '@go.printf "$@"'
  run "$TEST_GO_SCRIPT" "$test_text"
  assert_success "$test_text"
}

@test "$SUITE: preserve blank lines" {
  local test_string=$'1234567890\n\n1234567890\n\n1234567890'
  create_test_go_script "@go.printf '%s' '$test_string'"
  COLUMNS=15 run "$TEST_GO_SCRIPT"
  assert_success "$test_string"
}

@test "$SUITE: don't add extra newline if format ends with one" {
  local test_string='1234567890'
  create_test_go_script "@go.printf '%s\n' '$test_string'" \
    "@go.printf '%s\n' '$test_string'"
  COLUMNS=15 run "$TEST_GO_SCRIPT"
  assert_success "$test_string"$'\n'"$test_string"
}

@test "$SUITE: don't chomp non-blank leading characters" {
  create_test_go_script "@go.printf '%s\n' '12345678901234567890    1234567890'"
  COLUMNS=15 run "$TEST_GO_SCRIPT"
  assert_success $'123456789012345\n67890\n1234567890'
}
