#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: fail if no 'setup' script exists" {
  run_log_script '@go.setup_project setup Hello, World!'
  assert_failure

  local setup_script="$TEST_GO_SCRIPTS_DIR/setup"
  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    FATAL "Create $setup_script before invoking @go.setup_project." \
    "$(test_script_stack_trace_item)"
}

@test "$SUITE: fail if the 'setup' script isn't executable" {
  if fs_missing_permission_support; then
    skip "Can't trigger condition on this file system"
  fi

  create_test_command_script 'setup' 'echo $*'
  chmod 600 "$TEST_GO_SCRIPTS_DIR/setup"

  run_log_script '@go.setup_project setup Hello, World!'
  assert_failure
  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    FATAL "$TEST_GO_SCRIPTS_DIR/setup is not executable." \
    "$(test_script_stack_trace_item)"
}

@test "$SUITE: setup project successfully using ./go script directly" {
  create_test_command_script 'setup' 'echo $*'

  run_log_script '@go.setup_project setup Hello, World!'
  assert_success

  local env_message="Run \`$TEST_GO_SCRIPT help env\` to see how to set up "
  env_message+='your shell environment for this project.'

  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    RUN    "${TEST_GO_SCRIPTS_RELATIVE_DIR}/setup Hello, World!" \
    'Hello, World!' \
    FINISH 'Project setup successful' \
    INFO   "Run \`$TEST_GO_SCRIPT help\` to see the available commands." \
    INFO   "$env_message"
}

@test "$SUITE: setup project successfully using ./go script shell function" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    '@go.setup_project setup "$@"'

  create_test_command_script 'setup' 'echo $*'

  run test-go Hello, World!
  assert_success
  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    RUN    "${TEST_GO_SCRIPTS_RELATIVE_DIR}/setup Hello, World!" \
    'Hello, World!' \
    FINISH 'Project setup successful' \
    INFO   "Run \`$TEST_GO_SCRIPT help\` to see the available commands."
}

@test "$SUITE: setup fails due to @go.log ERROR" {
  create_test_command_script 'setup' '@go.log ERROR 127 "$@"'
  run_log_script '@go.setup_project setup foo bar baz'
  assert_failure
  set_go_core_stack_trace_components
  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    RUN    "${TEST_GO_SCRIPTS_RELATIVE_DIR}/setup foo bar baz" \
    ERROR  'foo bar baz (exit status 127)' \
    FATAL  'Project setup failed (exit status 127)' \
    "$(test_script_stack_trace_item)"
}

@test "$SUITE: Bash setup script exits directly due to @go.log FATAL" {
  # Note that the "Project setup failed" message doesn't appear, because the
  # `setup` script was executed in the same Bash process.
  create_test_command_script 'setup' '@go.log FATAL 127 "$@"'
  run_log_script '@go.setup_project setup foo bar baz'
  assert_failure

  local setup_project_stack_trace_item="$(stack_trace_item \
    "$_GO_CORE_DIR/lib/log" '@go.setup_project' \
    '  _@go.run_command_script "$setup_script" "$@"')"
  local run_command_script_stack_trace_item

  set_go_core_stack_trace_components
  run_command_script_stack_trace_item="${GO_CORE_STACK_TRACE_COMPONENTS[0]}"

  assert_log_equals START "Project setup in $TEST_GO_ROOTDIR" \
    RUN    "${TEST_GO_SCRIPTS_RELATIVE_DIR}/setup foo bar baz" \
    FATAL  'foo bar baz (exit status 127)' \
    "  $TEST_GO_SCRIPTS_DIR/setup:2 source" \
    "$run_command_script_stack_trace_item" \
    "$setup_project_stack_trace_item" \
    "$(test_script_stack_trace_item)"
}
