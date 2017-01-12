#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

run_log_script_and_assert_status_and_output() {
  set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"
  local num_errors
  local expected

  run_log_script "$@" \
    '@go.log INFO  FYI' \
    '@go.log RUN   echo foo' \
    '@go.log WARN  watch out' \
    '@go.log ERROR uh-oh' \
    '@go.log FATAL oh noes!'

  if assert_failure; then
    expected=(INFO 'FYI'
      RUN   'echo foo'
      WARN  'watch out'
      ERROR 'uh-oh'
      FATAL 'oh noes!'
      "$(stack_trace_item_from_offset "$TEST_GO_SCRIPT")")

    assert_log_equals "${expected[@]}"
    return_from_bats_assertion "$?"
  else
    return_from_bats_assertion 1
  fi
}

@test "$SUITE: exit if adding output file after logging already initiaized" {
  local log_file="$TEST_GO_ROOTDIR/all.log"

  run_log_script \
    "@go.log INFO Hello, World!" \
    "@go.log_add_output_file '$log_file'"
  assert_failure
  assert_log_equals \
    INFO 'Hello, World!' \
    FATAL "Can't add new output file $log_file; logging already initialized" \
    "$(stack_trace_item "$_GO_CORE_DIR/lib/log" '@go.log_add_output_file' \
      "    @go.log FATAL \"Can't add new output file \$output_file;\" \\")" \
    "$(stack_trace_item_from_offset "$TEST_GO_SCRIPT")"
}

@test "$SUITE: add an output file for all log levels" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/all.log'"
  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/all.log")" 'all.log'
}

@test "$SUITE: add an output file for an existing log level" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'"
  assert_matches "^INFO +FYI$" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
}

@test "$SUITE: force formatted output in log file" {
  _GO_LOG_FORMATTING='true' run_log_script \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'" \
    "@go.log INFO Hello, World!"
  assert_success
  assert_log_equals "$(format_label INFO)" 'Hello, World!'
  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
}

@test "$SUITE: add an output file for a new log level" {
  local msg="This shouldn't appear in standard output or error."

  # Note that FOOBAR has the same number of characters as FINISH, currently the
  # longest log label name. If FINISH is ever removed without another
  # six-character label taking its place, the test may fail because of changes
  # in label padding. The fix would be to replace FOOBAR with a new name no
  # longer than the longest built-in log label.
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/foobar.log' 'FOOBAR'" \
    "@go.log FOOBAR \"$msg\""

  assert_matches "^FOOBAR +$msg$" \
    "$(< "$TEST_GO_ROOTDIR/foobar.log")" 'foobar.log'
}

@test "$SUITE: add output files for multiple log levels" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/error.log' 'ERROR,FATAL'"

  local error_log=()
  local item
  while IFS= read -r item; do
    error_log+=("$item")
  done <<<"$(< "$TEST_GO_ROOTDIR/error.log")"

  assert_equal '3' "${#error_log[@]}" 'Number of error log lines'
  assert_matches '^ERROR +uh-oh$' "${error_log[0]}" 'ERROR log message'
  assert_matches '^FATAL +oh noes!$' "${error_log[1]}" 'FATAL log message'
  assert_equal "$(stack_trace_item_from_offset "$TEST_GO_SCRIPT")" \
    "${error_log[2]}" 'FATAL stack trace'
}

@test "$SUITE: add output files for a mix of levels" {
  local msg="This shouldn't appear in standard output or error."

  # Same note regarding FOOBAR from the earlier test case applies.
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/all.log'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/error.log' 'ERROR,FATAL'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/foobar.log' 'FOOBAR'" \
    "@go.log FOOBAR \"$msg\""

  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/all.log")" 'all.log'
  assert_matches "^INFO +FYI$" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
  assert_matches "^FOOBAR +$msg$" \
    "$(< "$TEST_GO_ROOTDIR/foobar.log")" 'foobar.log'

  local error_log=()
  local item
  while IFS= read -r item; do
    error_log+=("$item")
  done <<<"$(< "$TEST_GO_ROOTDIR/error.log")"

  assert_equal '3' "${#error_log[@]}" 'Number of error log lines'
  assert_matches '^ERROR +uh-oh$' "${error_log[0]}" 'ERROR log message'
  assert_matches '^FATAL +oh noes!$' "${error_log[1]}" 'FATAL log message'
  assert_equal "$(stack_trace_item_from_offset "$TEST_GO_SCRIPT")" \
    "${error_log[2]}" 'FATAL stack trace'
}
