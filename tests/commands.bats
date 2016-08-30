#! /usr/bin/env bats

load environment
load assertions
load script_helper

declare BUILTIN_CMDS
declare BUILTIN_SCRIPTS
declare LONGEST_BUILTIN_NAME

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
   
  find_builtins
}

teardown() {
  remove_test_go_rootdir
}

find_builtins() {
  local cmd_script
  local cmd_name

  for cmd_script in $_GO_ROOTDIR/libexec/*; do
    if [[ ! (-f "$cmd_script" && -x "$cmd_script") ]]; then
      continue
    fi
    cmd_name="${cmd_script##*/}"
    BUILTIN_CMDS+=("$cmd_name")
    BUILTIN_SCRIPTS+=("$cmd_script")

    if [[ "${#cmd_name}" -gt "${#LONGEST_BUILTIN_NAME}" ]]; then
      LONGEST_BUILTIN_NAME="$cmd_name"
    fi
  done

  # Strip the rootdir to make output less noisy.
  BUILTIN_SCRIPTS=("${BUILTIN_SCRIPTS[@]#$_GO_ROOTDIR/}")
}

assert_command_scripts_equal() {
  local result
  local IFS=$'\n'
  unset 'lines[0]' 'lines[1]'
  set +o functrace
  assert_equal "$*" "${lines[*]#$_GO_ROOTDIR/}" "command scripts"
  result="$?"
  set -o functrace
  return "$result"
}

merge_scripts() {
  local args=("$@")
  local i=0
  local j=0
  local lhs
  local rhs
  local result=()

  while ((i != ${#all_scripts[@]} && j != ${#args[@]})); do
    lhs="${all_scripts[$i]#*/}"
    rhs="${args[$j]#*/}"

    if [[ "$lhs" < "$rhs" ]]; then
      result+=("${all_scripts[$i]}")
      ((++i))
    elif [[ "$lhs" = "$rhs" ]]; then
      result+=("${all_scripts[$i]}")
      ((++i))
      ((++j))
    else
      result+=("${args[$j]}")
      ((++j))
    fi
  done

  while ((i != ${#all_scripts[@]})); do
    result+=("${all_scripts[$i]}")
    ((++i))
  done

  while ((j != ${#args[@]})); do
    result+=("${args[$j]}")
    ((++j))
  done

  all_scripts=("${result[@]}")
}

@test "commands: find returns only builtin commands" {
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "commands: find ignores directories" {
  mkdir $TEST_GO_SCRIPTS_DIR/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "commands: find ignores nonexecutable files" {
  if [[ -n "$COMSPEC" ]]; then
    skip "All files are executable on Windows"
  fi

  touch $TEST_GO_SCRIPTS_DIR/{foo,bar,baz}
  chmod 600 $TEST_GO_SCRIPTS_DIR/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "commands: find returns builtins and user scripts" {
  local longest_name="extra-long-name-that-no-one-would-use"
  local user_commands=('bar' 'baz' "$longest_name" 'foo')
  local all_scripts=("${BUILTIN_SCRIPTS[@]}")

  merge_scripts "${user_commands[@]/#/$TEST_GO_SCRIPTS_RELATIVE_DIR/}"
  touch "${user_commands[@]/#/$TEST_GO_SCRIPTS_DIR/}"
  chmod 700 $TEST_GO_SCRIPTS_DIR/*

  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${all_scripts[*]#**/}"
  assert_command_scripts_equal "${all_scripts[@]}"
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
