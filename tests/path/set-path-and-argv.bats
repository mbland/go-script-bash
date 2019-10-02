#! /usr/bin/env bats

load ../environment

setup() {
  @go.create_test_go_script \
    '. "$_GO_CORE_DIR/lib/internal/path"' \
    'if ! _@go.set_command_path_and_argv "$@"; then' \
    '  exit 1' \
    'fi' \
    'echo "PATH: $__go_cmd_path"' \
    'echo "NAME: ${__go_cmd_name[*]}"' \
    'echo "ARGV: ${__go_argv[*]}"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: error on empty argument list" {
  run "$TEST_GO_SCRIPT"
  assert_failure

  run "$TEST_GO_SCRIPT" '' '' ''
  assert_failure
}

@test "$SUITE: find builtin command" {
  local builtins=("$_GO_ROOTDIR"/libexec/*)
  local builtin_cmd="${builtins[0]}"

  run "$TEST_GO_SCRIPT" "${builtin_cmd##*/}" '--exists' 'ls'
  assert_success
  assert_line_equals 0 "PATH: $builtin_cmd"
  assert_line_equals 1 "NAME: ${builtin_cmd##*/}"
  assert_line_equals 2 'ARGV: --exists ls'
}

@test "$SUITE: list available commands if command not found" {
  # Since _@go.list_available_commands is already tested in isolation, we only
  # check the beginning of the error output.
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure

  assert_line_equals 0 'Unknown command: foobar'
  assert_line_equals 1 'Available commands are:'
}

@test "$SUITE: find top-level command" {
  # chmod is neutralized in MSYS2 on Windows; `#!` makes files executable.
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/foobar"
  chmod 700 "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar' 'baz' 'quux'
  assert_success
  assert_line_equals 0 "PATH: $TEST_GO_SCRIPTS_DIR/foobar"
  assert_line_equals 1 'NAME: foobar'
  assert_line_equals 2 'ARGV: baz quux'
}

@test "$SUITE: empty string argument is not an error" {
  # This is most likely to happen during argument completion, but could be valid
  # in the general case as well, depending on the command implementation.
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/foobar"
  chmod 700 "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar' '' 'baz' 'quux'
  assert_success
  assert_line_equals 0 "PATH: $TEST_GO_SCRIPTS_DIR/foobar"
  assert_line_equals 1 'NAME: foobar'
  assert_line_equals 2 'ARGV:  baz quux'
}

@test "$SUITE: error if top-level command name is a directory" {
  mkdir "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure
  assert_line_equals 0 "Unknown command: foobar"
}

@test "$SUITE: error if top-level command script is not executable" {
  touch "$TEST_GO_SCRIPTS_DIR/foobar"
  chmod 600 "$TEST_GO_SCRIPTS_DIR/foobar"
  run "$TEST_GO_SCRIPT" 'foobar'
  assert_failure
  assert_line_equals 0 "Unknown command: foobar"
}

@test "$SUITE: find subcommand" {
  local cmd_path="$TEST_GO_SCRIPTS_DIR/foobar"
  echo '#!' > "$cmd_path"
  chmod 700 "$cmd_path"
  mkdir "${cmd_path}.d"

  local subcmd_path="${cmd_path}.d/baz"
  echo '#!' > "$subcmd_path"
  chmod 700 "$subcmd_path"

  run "$TEST_GO_SCRIPT" 'foobar' 'baz' 'quux'
  assert_success
  assert_line_equals 0 "PATH: $TEST_GO_SCRIPTS_DIR/foobar.d/baz"
  assert_line_equals 1 'NAME: foobar baz'
  assert_line_equals 2 'ARGV: quux'
}

@test "$SUITE: merge commands from different script dirs" {
  create_bats_test_script scripts/foobar 'echo foobar'
  create_bats_test_script scripts/foobar.d/baz 'echo baz'
  create_bats_test_script scripts/foobar.d/quux 'echo quux'
  create_bats_test_script scripts-2/foobar 'echo foobar'
  create_bats_test_script scripts-2/foobar.d/baz 'echo baz2'
  create_bats_test_script scripts-2/foobar.d/aaa 'echo aaa'

  create_bats_test_script 'go' \
    ". '$_GO_CORE_DIR/go-core.bash' 'scripts' 'scripts-2'" \
    '@go "$@"'

  run "$TEST_GO_SCRIPT" 'foobar'
  assert_success
  assert_output_matches foobar

  run "$TEST_GO_SCRIPT" 'foobar' 'baz'
  assert_success
  assert_output_matches baz

  run "$TEST_GO_SCRIPT" 'foobar' 'quux'
  assert_success
  assert_output_matches quux

  run "$TEST_GO_SCRIPT" 'foobar' 'aaa'
  assert_success
  assert_output_matches aaa
}
