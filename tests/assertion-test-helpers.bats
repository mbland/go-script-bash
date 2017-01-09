#! /usr/bin/env bats

load environment

ASSERTION_SOURCE="$_GO_CORE_DIR/tests/assertion-test-helpers.bash"
load "$_GO_CORE_DIR/lib/bats/assertion-test-helpers"

EXPECT_ASSERTION_TEST_SCRIPT="run-expect-assertion.bats"
EXPECTED_TEST_SCRIPT_FAILURE_MESSAGE=

setup() {
  test_filter
  export ASSERTION=
  printf -v 'EXPECTED_TEST_SCRIPT_FAILURE_MESSAGE' \
    "${ASSERTION_TEST_SCRIPT_FAILURE_MESSAGE//$'\n'/$'\n# '}" "test_assertion"
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
  set +eET
  local test_script="$BATS_TEST_ROOTDIR/$EXPECT_ASSERTION_TEST_SCRIPT"
  local assertion_line="${ASSERTION%%$'\n'*}"
  local expected_output
  local result='0'

  printf -v expected_output '%s\n' \
    '1..1' \
    "not ok 1 $BATS_TEST_DESCRIPTION" \
    "# (in test file $test_script, line 7)" \
    "#   \`$assertion_line' failed" \
    "$@"
  # Trim the trailing newline, as it will've been from `output`.
  expected_output="${expected_output%$'\n'}"

  # We have to trim the last newline off the expected message, since it will've
  # been trimmed from `output`.
  if [ "$output" != "${expected_output}" ]; then
    printf 'EXPECTED:\n%s\nACTUAL:\n%s\n' "${expected_output}" "$output" >&2
    __return_from_check_failure_output '1'
  else
    __return_from_check_failure_output
  fi
}

__return_from_check_failure_output() {
  unset 'BATS_CURRENT_STACK_TRACE[0]' 'BATS_PREVIOUS_STACK_TRACE[0]'
  set -eET
  return "${1:-0}"
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
  [ "$status" -eq '1' ]

  check_failure_output '# In subshell: expected passing status, actual 127' \
    '# Output:' \
    '# foo bar baz'
}

@test "$SUITE: expected success, but failed and wrote to fd other than 2 " {
  ASSERTION_STATUS='127' ASSERTION_FD='1' run_assertion_test 'success'
  [ "$status" -eq '1' ]
  check_failure_output \
    "# 'test_assertion' tried to write to a file descriptor other than 2"
}

@test "$SUITE: successful assertion doesn't call return_from_bats_assertion" {
  SKIP_RETURN_FROM_BATS_ASSERTION='true' run_assertion_test 'success'
  [ "$status" -eq '1' ]

  local test_script="$ASSERTION_TEST_SCRIPT"
  check_failure_output '# Actual output differs from expected output:' \
    '# --------' \
    '# EXPECTED:' \
    '# 1..1' \
    "# not ok 1 $BATS_TEST_DESCRIPTION" \
    "# # (from function \`failing_assertion' in file $test_script, line 5," \
    "# #  in test file $test_script, line 7)" \
    "# #   \`failing_assertion' failed" \
    '# --------' \
    '# ACTUAL:' \
    '# 1..1' \
    "# ok 1 $BATS_TEST_DESCRIPTION" \
    '# --------' \
    "# $EXPECTED_TEST_SCRIPT_FAILURE_MESSAGE"
}

@test "$SUITE: failing assertion" {
  ASSERTION_STATUS='1' run_assertion_test 'failure' 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '0' ]
  [ "$output" == $'1..1\nok 1 '"$BATS_TEST_DESCRIPTION" ]
}

@test "$SUITE: failing assertion with status other than 1" {
  ASSERTION_STATUS='127' run_assertion_test 'failure' 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '0' ]
  [ "$output" == $'1..1\nok 1 '"$BATS_TEST_DESCRIPTION" ]
}

@test "$SUITE: failing assertion output must go to standard error" {
  ASSERTION_STATUS='1' ASSERTION_FD=1 run_assertion_test 'failure' 'foo bar baz'
  [ "$status" -eq '1' ]
  check_failure_output \
    "# 'test_assertion' tried to write to a file descriptor other than 2"
}

@test "$SUITE: expected_failure, but assertion succeeds" {
  ASSERTION_STATUS='0' run_assertion_test 'failure' 'foo bar baz'
  [ "$status" -eq '1' ]

  check_failure_output '# In subshell: expected failure, but succeeded' \
    '# Output:' \
    '# '
}

@test "$SUITE: failing assertion doesn't disable shell options" {
  ASSERTION_STATUS='1' TEST_ASSERTION_SHELL_OPTIONS='-eET' \
    run_assertion_test 'failure' 'foo bar baz'
  [ "$status" -eq '1' ]

  local test_script="$ASSERTION_TEST_SCRIPT"
  local impl_file="${ASSERTION_SOURCE#$_GO_CORE_DIR/}"
  check_failure_output '# Actual output differs from expected output:' \
    '# --------' \
    '# EXPECTED:' \
    '# 1..1' \
    "# not ok 1 $BATS_TEST_DESCRIPTION" \
    "# # (in test file $test_script, line 5)" \
    "# #   \`test_assertion \"\$output\"' failed" \
    '# # foo bar baz' \
    '# --------' \
    '# ACTUAL:' \
    '# 1..1' \
    "# not ok 1 $BATS_TEST_DESCRIPTION" \
    "# # (from function \`__test_assertion_impl' in file $impl_file, line 13," \
    "# #  from function \`test_assertion' in file $impl_file, line 22," \
    "# #  in test file $test_script, line 5)" \
    "# #   \`test_assertion \"\$output\"' failed" \
    '# # foo bar baz' \
    '# --------' \
    "# $EXPECTED_TEST_SCRIPT_FAILURE_MESSAGE"
}

@test "$SUITE: failing assertion doesn't call return_from_bats_assertion" {
  ASSERTION_STATUS='1' SKIP_RETURN_FROM_BATS_ASSERTION='true' \
    run_assertion_test 'failure' 'foo bar baz'
  [ "$status" -eq '1' ]

  local test_script="$ASSERTION_TEST_SCRIPT"
  check_failure_output '# Actual output differs from expected output:' \
    '# --------' \
    '# EXPECTED:' \
    '# 1..1' \
    "# not ok 1 $BATS_TEST_DESCRIPTION" \
    "# # (in test file $test_script, line 5)" \
    "# #   \`test_assertion \"\$output\"' failed" \
    '# # foo bar baz' \
    '# --------' \
    '# ACTUAL:' \
    '# 1..1' \
    "# ok 1 $BATS_TEST_DESCRIPTION" \
    '# --------' \
    "# $EXPECTED_TEST_SCRIPT_FAILURE_MESSAGE"
}
