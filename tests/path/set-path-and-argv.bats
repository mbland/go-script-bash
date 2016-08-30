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

@test "path/argv: error on empty argument list" {
  run "$TEST_GO_SCRIPT"
  assert_failure

  run "$TEST_GO_SCRIPT" '' '' ''
  assert_failure
}

@test "path/argv: find builtin command" {
  local builtins=($_GO_ROOTDIR/libexec/*)
  local builtin_cmd="${builtins[0]}"

  run "$TEST_GO_SCRIPT" "${builtin_cmd##*/}" '--exists' 'ls'
  assert_success
  assert_line_equals 0 "PATH: $builtin_cmd"
  assert_line_equals 1 'ARGV: --exists ls'
}

@test "path/argv: list available commands if command not found" {
  # Since _@go.list_available_commands is already tested in isolation, we only
  # check the beginning of the error output.
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure

  assert_line_equals 0 'Unknown command: foobar'
  assert_line_equals 1 'Available commands are:'
}

@test "path/argv: find top-level command" {
  touch "$TEST_GO_SCRIPTS_DIR/foobar"
  chmod 700 "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar' 'baz' 'quux'
  assert_success
  assert_line_equals 0 "PATH: $TEST_GO_SCRIPTS_DIR/foobar"
  assert_line_equals 1 'ARGV: baz quux'
}

@test "path/argv: error if top-level command name is a directory" {
  mkdir "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure
  assert_line_equals 0 "$TEST_GO_SCRIPTS_DIR/foobar is not an executable script"
}

@test "path/argv: error if top-level command script is not executable" {
  touch "$TEST_GO_SCRIPTS_DIR/foobar"
  chmod 600 "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure
  assert_line_equals 0 "$TEST_GO_SCRIPTS_DIR/foobar is not an executable script"
}
