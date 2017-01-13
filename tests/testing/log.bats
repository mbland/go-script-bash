#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/testing/log"

setup() {
  test_filter
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: create_log_script and run_log_script without log file" {
  export TEST_LOG_FILE="$TEST_GO_ROOTDIR/test-script.log"
  TEST_LOG_FILE= run_log_script '@go.log INFO Hello, World!'
  assert_success
  assert_output_matches '^INFO +Hello, World!$'
  [ ! -e "$TEST_LOG_FILE" ]
}

@test "$SUITE: create_log_script and run_log_script with log file" {
  export TEST_LOG_FILE="$TEST_GO_ROOTDIR/test-script.log"
  run_log_script '@go.log INFO Hello, World!'
  assert_success
  assert_output_matches '^INFO +Hello, World!$'
  [ -e "$TEST_LOG_FILE" ]
  assert_file_matches "$TEST_LOG_FILE" '^INFO +Hello, World!$'
}

@test "$SUITE: set_log_command_stack_trace_items" {
  assert_equal '' "${LOG_COMMAND_STACK_TRACE_ITEMS[*]}"
  set_log_command_stack_trace_items
  lines=("${LOG_COMMAND_STACK_TRACE_ITEMS[@]}")
  assert_lines_match \
    "^  $_GO_CORE_DIR/lib/log:[0-9]+ _@go.log_command_invoke$" \
    "^  $_GO_CORE_DIR/lib/log:[0-9]+ @go.log_command$"
}

@test "$SUITE: format_log_label" {
  run format_log_label INFO
  assert_success

  local expected_message
  printf -v expected_message '%b' "$output Hello, World!\e[0m"

  _GO_LOG_FORMATTING='true' run_log_script '@go.log INFO Hello, World!'
  assert_success "$expected_message"
}

@test "$SUITE: format_log_label exits if log module already initialized" {
  __GO_LOG_INIT='true' run format_log_label INFO
  assert_failure
  assert_output_matches '^`format_log_label` must be called before any other '
}

@test "$SUITE: format_log_label exits if log level label invalid" {
  run format_log_label FOOBAR
  assert_failure 'Unknown log level label: FOOBAR'
}
