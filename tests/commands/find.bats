#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  create_test_go_script \
    '. "$_GO_CORE_DIR/lib/internal/path"' \
    '. "$_GO_CORE_DIR/lib/internal/commands"' \
    'declare __go_longest_name_len' \
    'declare __go_command_names' \
    'declare __go_command_scripts' \
    'if ! _@go.find_commands "${@:-${_GO_SEARCH_PATHS[@]}}"; then' \
    '  exit 1' \
    'fi' \
    'echo LONGEST NAME LEN: "$__go_longest_name_len"' \
    'echo COMMAND_NAMES: "${__go_command_names[@]}"' \
    "IFS=$'\n'" \
    'echo "${__go_command_scripts[*]}"' \

  find_builtins
}

teardown() {
  remove_test_go_rootdir
}

__assert_command_scripts_equal() {
  unset "BATS_PREVIOUS_STACK_TRACE[0]"
  local result
  local IFS=$'\n'
  unset 'lines[0]' 'lines[1]'
  assert_equal "$*" "${lines[*]#$_GO_ROOTDIR/}" "command scripts"
}

assert_command_scripts_equal() {
  set +o functrace
  __assert_command_scripts_equal "$@"
}

@test "$SUITE: return only builtin commands" {
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: ignore directories" {
  mkdir "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: ignore nonexecutable files" {
  touch "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  chmod 600 "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: return builtins and user scripts" {
  local longest_name="extra-long-name-that-no-one-would-use"
  # user_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' "$longest_name" 'foo')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${__all_scripts[*]##*/}"
  assert_command_scripts_equal "${__all_scripts[@]}"
}

@test "$SUITE: return builtins, plugins, and user scripts" {
  local longest_name="super-extra-long-name-that-no-one-would-use"
  # user_commands and plugin_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' "$longest_name" 'xyzzy')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${__all_scripts[*]##*/}"
  assert_command_scripts_equal "${__all_scripts[@]}"
}

@test "$SUITE: return error if duplicates exists" {
  local duplicate_cmd="${BUILTIN_SCRIPTS[0]##*/}"
  local user_commands=("$duplicate_cmd")
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  run "$TEST_GO_SCRIPT"
  assert_failure

  assert_line_equals 0 "ERROR: duplicate command $duplicate_cmd:"

  # Because the go-core.bash file is in the test's $_GO_ROOTDIR, and the test
  # script has a different $_GO_ROOTDIR, the builtin scripts will retain their
  # absolute path, whereas user scripts will be relative.
  assert_line_equals 1 "  $_GO_ROOTDIR/${BUILTIN_SCRIPTS[0]}"
  assert_line_equals 2 "  scripts/$duplicate_cmd"
}

@test "$SUITE: return subcommands only" {
  # parent_commands and subcommands must remain hand-sorted
  local longest_name='terribly-long-name-that-would-be-insane-in-a-real-script'
  local parent_commands=('bar' 'baz' 'foo')
  local subcommands=('plugh' 'quux' "$longest_name" 'xyzzy')
  local __all_scripts=()

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${parent_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/foo.d" "${subcommands[@]}"
  run "$TEST_GO_SCRIPT" "$TEST_GO_SCRIPTS_RELATIVE_DIR/foo.d"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${subcommands[*]}"
  assert_command_scripts_equal "${subcommands[@]/#/scripts/foo.d/}"
}

@test "$SUITE: return error if no commands are found" {
  mkdir "$TEST_GO_SCRIPTS_DIR/foo.d"
  run "$TEST_GO_SCRIPT" "$TEST_GO_SCRIPTS_RELATIVE_DIR/foo.d"
  assert_failure ''
}

@test "$SUITE: error if no commands are found because dir doesn't exist" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_SCRIPTS_RELATIVE_DIR/foo.d"
  assert_failure ''
}
