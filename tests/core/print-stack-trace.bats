#! /usr/bin/env bats

load ../environment

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: stack trace from top level of main ./go script" {
  create_test_go_script '@go.print_stack_trace'
  run "$TEST_GO_SCRIPT"
  assert_success "  $TEST_GO_SCRIPT:3 main"
}

@test "$SUITE: stack trace from top level of main ./go script without caller" {
  create_test_go_script '@go.print_stack_trace 1'
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: stack trace from function inside main ./go script" {
  create_test_go_script \
    'print_stack() {' \
    '  @go.print_stack_trace' \
    '}' \
    'print_stack'
  run "$TEST_GO_SCRIPT"

  local expected=("  $TEST_GO_SCRIPT:4 print_stack"
    "  $TEST_GO_SCRIPT:6 main")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: omit function caller from stack trace" {
  create_test_go_script \
    'print_stack() {' \
    "  @go.print_stack_trace 1" \
    '}' \
    'print_stack'
  run "$TEST_GO_SCRIPT"
  assert_success "  $TEST_GO_SCRIPT:6 main"
}

@test "$SUITE: bad skip_callers argument prints entire trace" {
  create_test_go_script \
    'print_stack() {' \
    "  @go.print_stack_trace foobar" \
    '}' \
    'print_stack'
  run "$TEST_GO_SCRIPT"

  local error_msg=("@go.print_stack_trace argument 'foobar' not a positive"
    'integer; printing full stack')
  assert_failure
  assert_line_equals 0 "${error_msg[*]}"
  assert_line_equals 1 "  $TEST_GO_SCRIPT:4 print_stack"
  assert_line_equals 2 "  $TEST_GO_SCRIPT:6 main"
}

@test "$SUITE: skipping too many callers prints entire trace" {
  create_test_go_script \
    'print_stack() {' \
    "  @go.print_stack_trace 100" \
    '}' \
    'print_stack'
  run "$TEST_GO_SCRIPT"

  local error_msg=('@go.print_stack_trace argument 100 exceeds stack size 2;'
    'printing full stack')
  assert_failure
  assert_line_equals 0 "${error_msg[*]}"
  assert_line_equals 1 "  $TEST_GO_SCRIPT:4 print_stack"
  assert_line_equals 2 "  $TEST_GO_SCRIPT:6 main"
}

@test "$SUITE: stack trace from subcommand script" {
  create_test_go_script '@go "$@"'
  create_test_command_script 'foo' \
    'foo_func() {' \
    '  @go foo bar' \
    '}' \
    'foo_func'
  create_test_command_script 'foo.d/bar' \
    'bar_func() {' \
    '  @go.print_stack_trace 1' \
    '}' \
    'bar_func'

  run "$TEST_GO_SCRIPT" foo

  local go_core_pattern="$_GO_CORE_DIR/go-core.bash:[0-9]+"
  assert_success
  assert_line_equals  0 "  $TEST_GO_SCRIPTS_DIR/foo.d/bar:5 source"
  assert_line_matches 1 "  $go_core_pattern _@go.run_command_script"
  assert_line_matches 2 "  $go_core_pattern @go"
  assert_line_equals  3 "  $TEST_GO_SCRIPTS_DIR/foo:3 foo_func"
  assert_line_equals  4 "  $TEST_GO_SCRIPTS_DIR/foo:5 source"
  assert_line_matches 5 "  $go_core_pattern _@go.run_command_script"
  assert_line_matches 6 "  $go_core_pattern @go"
  assert_line_equals  7 "  $TEST_GO_SCRIPT:3 main"
}
