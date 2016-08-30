#! /usr/bin/env bats

load environment
load assertions
load script_helper

setup() {
  create_test_go_script \
    '. "$_GO_CORE_DIR/lib/path"' \
    '. "$_GO_CORE_DIR/lib/commands"' \
    'declare __go_longest_name_len' \
    'declare __go_command_names' \
    'declare __go_command_scripts' \
    '_@go.find_commands "${_GO_SEARCH_PATHS[@]}"' \
    'STATUS="$?"' \
    'echo LONGEST NAME LEN: "$__go_longest_name_len"' \
    'echo COMMAND_NAMES: "${__go_command_names[@]}"' \
    "IFS=$'\n'" \
    'echo "${__go_command_scripts[*]}"' \
    'exit "$STATUS"'
}

teardown() {
  remove_test_go_rootdir
}

_find_builtins() {
  local cmd_script
  local cmd_name

  for cmd_script in $_GO_ROOTDIR/libexec/*; do
    if [[ ! (-f "$cmd_script" && -x "$cmd_script") ]]; then
      continue
    fi
    cmd_name="${cmd_script##*/}"
    __builtin_cmds+=("$cmd_name")
    __builtin_scripts+=("$cmd_script")

    if [[ "${#cmd_name}" -gt "${#__longest_name}" ]]; then
      __longest_name="$cmd_name"
    fi
  done
}

_assert_command_scripts_equal() {
  local result
  local IFS=$'\n'
  unset 'lines[0]' 'lines[1]'
  set +o functrace
  assert_equal "$*" "${lines[*]#$_GO_ROOTDIR/}" "command scripts"
  result="$?"
  set -o functrace
  return "$result"
}

@test "commands: find returns only builtin commands" {
  run "$TEST_GO_SCRIPT"
  assert_success

  local __builtin_cmds
  local __builtin_scripts
  local __longest_name
  _find_builtins

  assert_line_equals 0 "LONGEST NAME LEN: ${#__longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${__builtin_cmds[*]}"
  _assert_command_scripts_equal "${__builtin_scripts[@]#$_GO_ROOTDIR/}"
}

@test "commands: find returns builtins and user scripts" {
  skip
}

@test "commands: find returns builtins, plugins, and user scripts" {
  skip
}

@test "commands: find returns error if duplicates exists" {
  skip
}

@test "commands: find returns error if no commands are found" {
  skip
}
