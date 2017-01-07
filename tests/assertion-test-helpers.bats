#! /usr/bin/env bats

load environment

ASSERTION_SOURCE="$_GO_CORE_DIR/tests/assertion-test-helpers.bash"
load "$_GO_CORE_DIR/lib/bats/assertion-test-helpers"

EXPECT_ASSERTION_TEST_SCRIPT="run-expect-assertion.bats"

setup() {
  test_filter
  export ASSERTION=
}

teardown() {
  remove_bats_test_dirs
}

emit_debug_info() {
  printf 'STATUS: %s\nOUTPUT:\n%s\n' "$status" "$output" >&2
}

run_assertion_test() {
  local expected_output=("${@:2}")
  local expected_output_line

  ASSERTION="expect_assertion_${1}"
  ASSERTION+=" 'echo foo bar baz' 'test_assertion \"\$output\"'"

  for expected_output_line in "${expected_output[@]}"; do
    ASSERTION+=$' \\\n    '"'$expected_output_line'"
  done

  create_bats_test_script "$EXPECT_ASSERTION_TEST_SCRIPT" \
    '#! /usr/bin/env bats' \
    '' \
    "ASSERTION_SOURCE='$ASSERTION_SOURCE'" \
    ". '$_GO_CORE_DIR/lib/bats/assertion-test-helpers'" \
    '' \
    "@test \"$BATS_TEST_DESCRIPTION\" {" \
    "  $ASSERTION" \
    '}'
  run "$BATS_TEST_ROOTDIR/$EXPECT_ASSERTION_TEST_SCRIPT"
}

check_failure_output() {
  local test_script="$BATS_TEST_ROOTDIR/$EXPECT_ASSERTION_TEST_SCRIPT"
  local assertion_line="${ASSERTION%%$'\n'*}"
  local actual_failure_message="${output#*$'\n#  in test file '}"
  local expected_failure_message

  printf -v expected_failure_message '%s\n' \
    "$test_script, line 7)" \
    "#   \`$assertion_line' failed" \
    "$@"

  # We have to trim the last newline off the expected message, since it will've
  # been trimmed from `output`.
  [ "$actual_failure_message" == "${expected_failure_message%$'\n'}" ]
}

@test "$SUITE: printf_with_error" {
  run printf_with_error 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '1' ]
  [ "$output" == 'foo bar baz' ]

  PRINTF_ERROR='127' run printf_with_error 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '127' ]
  [ "$output" == 'foo bar baz' ]
}

@test "$SUITE: printf_to_test_output_file" {
  run printf_to_test_output_file 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '0' ]
  [ -z "$output" ]
  [ "$(< "$TEST_OUTPUT_FILE")" == 'foo bar baz' ]
}

@test "$SUITE: error if ASSERTION_SOURCE not set" {
  ASSERTION_SOURCE= run_assertion_test
  emit_debug_info
  [ "$status" -eq '1' ]

  local err_msg='"ASSERTION_SOURCE" must be set before sourcing '
  err_msg+="$_GO_CORE_DIR/lib/bats/assertion-test-helpers."
  [ "$output" == "$err_msg" ]
}

@test "$SUITE: successful assertion" {
  run_assertion_test 'success'
  emit_debug_info
  [ "$status" -eq '0' ]
  [ "$output" == $'1..1\nok 1 '"$BATS_TEST_DESCRIPTION" ]
}

@test "$SUITE: expected success, but failed with nonzero status" {
  ASSERTION_STATUS='127' run_assertion_test 'success'
  emit_debug_info
  [ "$status" -eq '1' ]

  local output_begin="${output%%$'\n'#*}"
  [ "$output_begin" == $'1..1\nnot ok 1 '"$BATS_TEST_DESCRIPTION" ]

  check_failure_output '# In subshell: expected passing status, actual 127' \
    '# Output:' \
    '# foo bar baz'
}
