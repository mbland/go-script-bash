#! /usr/bin/env bats

load ../environment

TEST_TEXT='1234567890 1234567890 1234567890'

setup() {
  create_test_go_script '@go.printf "%s" "$@"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: wrap text according to COLUMNS if fold command is available" {
  run env COLUMNS=11 "$TEST_GO_SCRIPT" "$TEST_TEXT"
  assert_success
  assert_equal '3' "${#lines[@]}" 'number of output lines'
  assert_line_equals 0 '1234567890 '
  assert_line_equals 1 '1234567890 '
  assert_line_equals 2 '1234567890'
}

@test "$SUITE: don't wrap text if fold command isn't available" {
  run env PATH= COLUMNS=11 "$BASH" "$TEST_GO_SCRIPT" "$TEST_TEXT"
  assert_success "$TEST_TEXT"
  assert_equal '1' "${#lines[@]}" 'number of output lines'
}

@test "$SUITE: escape percent signs if only one argument" {
  local test_text='This contains a suffix deletion: ${FOO%/*}'
  create_test_go_script '@go.printf "$@"'
  run "$TEST_GO_SCRIPT" "$test_text"
  assert_success "$test_text"
}
