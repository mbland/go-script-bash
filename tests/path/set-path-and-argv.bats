#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

setup() {
  create_test_go_script \
    '. "$_GO_CORE_DIR/lib/path"' \
    'if ! _@go.set_command_path_and_argv "$@"; then' \
    '  exit 1' \
    'fi' \
    'echo "PATH: $__go_cmd_path"' \
    'echo "ARGV: ${__go_argv[@]}"'
}

teardown() {
  remove_test_go_rootdir
}

@test "path+argv: error on empty argument list" {
  run "$TEST_GO_SCRIPT"
  assert_failure

  run "$TEST_GO_SCRIPT" '' '' ''
  assert_failure
}

@test "path+argv: list available commands if command not found" {
  # Since we aren't creating any new commands, and _@go.find_commands is already
  # thoroughly tested in isolation, we only check that builtins are available.
  local expected=($_GO_ROOTDIR/libexec/*)
  expected=("${expected[@]##*/}")

  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure

  assert_line_equals 0 'Unknown command: foobar'
  assert_line_equals 1 'Available commands are:'

  unset 'lines[0]' 'lines[1]'
  local IFS=$'\n'
  assert_equal "${expected[*]/#/  }" "${lines[*]}" 'available commands'
}

@test "path+argv: error if command not found and no commands available" {
  # Overwrite the script to isolate _@go.list_available_commands.
  create_test_go_script \
    '. "$_GO_CORE_DIR/lib/path"' \
    "_@go.list_available_commands \"$TEST_GO_SCRIPTS_DIR\""
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure

  assert_line_equals 0 'ERROR: No commands available in:'
  assert_line_equals 1 "  $TEST_GO_SCRIPTS_DIR"
}

@test "path+argv: find builtin command" {
  local builtins=($_GO_ROOTDIR/libexec/*)
  local builtin_cmd="${builtins[0]}"

  run "$TEST_GO_SCRIPT" "${builtin_cmd##*/}" '--exists' 'ls'
  assert_success
  assert_line_equals 0 "PATH: $builtin_cmd"
  assert_line_equals 1 "ARGV: --exists ls"
}
