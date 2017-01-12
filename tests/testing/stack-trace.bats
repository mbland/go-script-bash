#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/testing/stack-trace"

EXPECTED_TEST_SCRIPT=

setup() {
  test_filter
  EXPECTED_TEST_GO_SCRIPT=('#! /usr/bin/env bash'
    ". '$_GO_CORE_DIR/go-core.bash' '$TEST_GO_SCRIPTS_RELATIVE_DIR'"
    '@go "$@"')
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: count_lines" {
  create_test_go_script '@go "$@"'
  assert_file_equals "$TEST_GO_SCRIPT" "${EXPECTED_TEST_GO_SCRIPT[@]}"

  local num_lines=0
  count_lines "$TEST_GO_SCRIPT" 'num_lines'
  assert_equal "${#EXPECTED_TEST_GO_SCRIPT[@]}" "$num_lines"
}

@test "$SUITE: count_lines aborts if file not specified" {
  run count_lines
  assert_failure 'No file specified for `count_lines`.'
}

@test "$SUITE: count_lines aborts if file missing" {
  run count_lines "$TEST_GO_SCRIPT" 'num_lines'
  assert_failure "Create \"$TEST_GO_SCRIPT\" before calling \`count_lines\`."
}

@test "$SUITE: count_lines aborts if result variable not specified" {
  create_test_go_script '@go "$@"'
  run count_lines "$TEST_GO_SCRIPT"
  assert_failure 'No result variable specified for `count_lines`.'
}

@test "$SUITE: stack_trace_item_from_offset reports last line:main by default" {
  create_test_go_script '@go "$@"'
  run stack_trace_item_from_offset "$TEST_GO_SCRIPT"
  assert_success "  $TEST_GO_SCRIPT:${#EXPECTED_TEST_GO_SCRIPT[@]} main"
}

@test "$SUITE: stack_trace_item_from_offset reports specified line, function" {
  create_test_go_script '@go "$@"'
  run stack_trace_item_from_offset "$TEST_GO_SCRIPT" '1' 'funcname'

  local expected_lineno="$((${#EXPECTED_TEST_GO_SCRIPT[@]} - 1))"
  assert_success "  $TEST_GO_SCRIPT:$expected_lineno funcname"
}

@test "$SUITE: stack_trace_item_from_offset aborts if file not specified" {
  run stack_trace_item_from_offset
  assert_failure 'No file specified for `stack_trace_item_from_offset`.'
}

@test "$SUITE: set_go_core_stack_trace_components" {
  assert_equal '' "${GO_CORE_STACK_TRACE_COMPONENTS[*]}"
  set_go_core_stack_trace_components
  lines=("${GO_CORE_STACK_TRACE_COMPONENTS[@]}")
  assert_lines_match \
    "^  $_GO_CORE_DIR/go-core.bash:[0-9]+ _@go.run_command_script$" \
    "^  $_GO_CORE_DIR/go-core.bash:[0-9]+ @go$"
}
