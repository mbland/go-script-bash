#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/testing/log"

setup() {
  test_filter
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: set_log_command_stack_trace_items" {
  assert_equal '' "${LOG_COMMAND_STACK_TRACE_ITEMS[*]}"
  set_log_command_stack_trace_items
  lines=("${LOG_COMMAND_STACK_TRACE_ITEMS[@]}")
  assert_lines_match \
    "^  $_GO_CORE_DIR/lib/log:[0-9]+ _@go.log_command_invoke$" \
    "^  $_GO_CORE_DIR/lib/log:[0-9]+ @go.log_command$"
}
