#! /usr/bin/env bats

load ../environment
load ../commands/helpers

setup() {
  create_test_go_script '. "$_GO_CORE_DIR/lib/internal/complete"' \
    'declare __go_complete_word_index' \
    'declare __go_cmd_path' \
    'declare __go_argv' \
    'declare result=0' \
    'if ! _@go.complete_command_path "$@"; then' \
    '  result=1' \
    'fi' \
    'echo "$__go_complete_word_index"' \
    'echo "$__go_cmd_path"' \
    'echo "${__go_argv[@]}"' \
    'if [[ $__go_complete_word_index -ge 0 ]]; then' \
    '  echo "${__go_argv[$__go_complete_word_index]}"' \
    'fi' \
    'exit "$result"'
  find_builtins
}

teardown() {
  remove_test_go_rootdir
}

__assert_outputs_match() {
  unset 'BATS_PREVIOUS_STACK_TRACE[0]'
  local num_expected_output_lines="${#__expected_output[@]}"
  local IFS=$'\n'

  assert_equal "${__expected_output[*]}" \
    "${lines[*]:0:$num_expected_output_lines}" 'output'

  local IFS=' '
  lines=("${lines[@]:$num_expected_output_lines}")

  assert_equal "$__expected_index" "${lines[0]}" 'word index'
  assert_equal "$__expected_path" "${lines[1]}" 'command path'
  assert_equal "${__expected_argv[*]}" "${lines[2]}" 'argument list'
  assert_equal "$__expected_word" "${lines[3]}" 'target word'
}

assert_outputs_match() {
  set +o functrace
  __assert_outputs_match "$@"
}

@test "$SUITE: error on empty arguments" {
  run "$TEST_GO_SCRIPT"
  assert_failure
  assert_outputs_match
}

@test "$SUITE: all top-level commands for zeroth or first argument" {
  # user_commands and plugin_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' 'xyzzy')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"

  # Aliases will get printed before all other commands.
  __all_scripts=($(./go 'aliases') "${__all_scripts[@]}")
  local __expected_output=("${__all_scripts[@]##*/}")
  local __expected_index=0

  run "$TEST_GO_SCRIPT" 0
  assert_success
  assert_outputs_match

  run "$TEST_GO_SCRIPT" 0 ''
  assert_success
  assert_outputs_match

  run "$TEST_GO_SCRIPT" 0 xyz
  __expected_output=('xyzzy')
  assert_success
  assert_outputs_match
}

@test "$SUITE: error on nonexistent command" {
  run "$TEST_GO_SCRIPT" 0 'foobar'
  # The first time fails because _@go.complete_top_level_commands gets executed.
  assert_failure
  local __expected_index=0
  assert_outputs_match

  # The second time fails because _@go.set_command_path_and_argv gets executed.
  run "$TEST_GO_SCRIPT" 1 'foobar' ''
  assert_failure
  assert_line_equals 0 'Unknown command: foobar'
}

@test "$SUITE: complete top-level command when other args present" {
  run "$TEST_GO_SCRIPT" 0 'pat' 'foo' 'bar'
  local __expected_output=('path')
  local __expected_index=0
  assert_success
  assert_outputs_match
}

@test "$SUITE: complete parent command" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 0 'foo'
  assert_success

  local __expected_output=('foo')
  local __expected_index=0
  assert_outputs_match
}

@test "$SUITE: complete all subcommands" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 1 'foo' ''
  assert_success

  local IFS=$'\n'
  local __expected_output=('bar' 'baz' 'quux')
  local __expected_index=0
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo"
  assert_outputs_match
}

@test "$SUITE: complete subcommands matching target word" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 1 'foo' 'b'
  assert_success

  local __expected_output=('bar' 'baz')
  local __expected_index=0
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo"
  local __expected_argv=('b')
  local __expected_word='b'
  assert_outputs_match
}

@test "$SUITE: complete subcommands matching target word with trailing args" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 1 'foo' 'b' 'xyzzy'
  assert_success

  local __expected_output=('bar' 'baz')
  local __expected_index=0
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo"
  local __expected_argv=('b' 'xyzzy')
  local __expected_word='b'
  assert_outputs_match
}

@test "$SUITE: fail to complete subcommand but still return success" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 1 'foo' 'bogus' 'xyzzy'
  assert_success

  local __expected_output=()
  local __expected_index=0
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo"
  local __expected_argv=('bogus' 'xyzzy')
  local __expected_word='bogus'
  assert_outputs_match
}

@test "$SUITE: successfully complete subcommand" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 1 'foo' 'bar' 'xyzzy'
  assert_success

  local __expected_output=('bar')
  local __expected_index=-1
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo.d/bar"
  local __expected_argv=('xyzzy')
  local __expected_word=''
  assert_outputs_match
}

@test "$SUITE: do not complete nonexistent subcommand of subcommand" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 2 'foo' 'bar' 'xyzzy'
  assert_success

  local __expected_output=()
  local __expected_index=0
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo.d/bar"
  local __expected_argv=('xyzzy')
  local __expected_word='xyzzy'
  assert_outputs_match
}

@test "$SUITE: set subcommand path but do not attempt to complete later arg" {
  create_parent_and_subcommands 'foo' 'bar' 'baz' 'quux'

  run "$TEST_GO_SCRIPT" 3 'foo' 'bar' 'xyzzy' 'frobozz'
  assert_success

  local __expected_output=()
  local __expected_index=1
  local __expected_path="$TEST_GO_SCRIPTS_DIR/foo.d/bar"
  local __expected_argv=('xyzzy' 'frobozz')
  local __expected_word='frobozz'
  assert_outputs_match
}
