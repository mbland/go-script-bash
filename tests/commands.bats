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

find_builtins() {
  local cmd_script
  local cmd_name

  for cmd_script in "$_GO_ROOTDIR"/libexec/*; do
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
    lhs="${all_scripts[$i]##*/}"
    rhs="${args[$j]##*/}"

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

  all_scripts=("${result[@]}" "${all_scripts[@]:$i}" "${args[@]:$j}")
}

add_scripts() {
  local scripts_dir="$1/"
  shift

  local relative_dir="${scripts_dir#$TEST_GO_ROOTDIR/}"
  local script_names=("$@")

  if [[ ! -d "$scripts_dir" ]]; then
    mkdir "$scripts_dir"
  fi

  merge_scripts "${script_names[@]/#/$relative_dir}"

  # chmod is neutralized in MSYS2 on Windows; `#!` makes files executable.
  local script_path
  for script_path in "${script_names[@]/#/$scripts_dir}"; do
    echo '#!' > "$script_path"
  done
  chmod 700 "${script_names[@]/#/$scripts_dir}"
}

@test "$SUITE: find returns only builtin commands" {
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: find ignores directories" {
  mkdir "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: find ignores nonexecutable files" {
  touch "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  chmod 600 "$TEST_GO_SCRIPTS_DIR"/{foo,bar,baz}
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#LONGEST_BUILTIN_NAME}"
  assert_line_equals 1 "COMMAND_NAMES: ${BUILTIN_CMDS[*]}"
  assert_command_scripts_equal "${BUILTIN_SCRIPTS[@]}"
}

@test "$SUITE: find returns builtins and user scripts" {
  local longest_name="extra-long-name-that-no-one-would-use"
  # user_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' "$longest_name" 'foo')
  local all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${all_scripts[*]##*/}"
  assert_command_scripts_equal "${all_scripts[@]}"
}

@test "$SUITE: find returns builtins, plugins, and user scripts" {
  local longest_name="super-extra-long-name-that-no-one-would-use"
  # user_commands and plugin_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' "$longest_name" 'xyzzy')
  local all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"
  run "$TEST_GO_SCRIPT"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${all_scripts[*]##*/}"
  assert_command_scripts_equal "${all_scripts[@]}"
}

@test "$SUITE: find returns error if duplicates exists" {
  local duplicate_cmd="${BUILTIN_SCRIPTS[0]##*/}"
  local user_commands=("$duplicate_cmd")
  local all_scripts=("${BUILTIN_SCRIPTS[@]}")

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

@test "$SUITE: find returns subcommands only" {
  # parent_commands and subcommands must remain hand-sorted
  local longest_name='terribly-long-name-that-would-be-insane-in-a-real-script'
  local parent_commands=('bar' 'baz' 'foo')
  local subcommands=('plugh' 'quux' "$longest_name" 'xyzzy')
  local all_scripts=()

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${parent_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/foo.d" "${subcommands[@]}"
  run "$TEST_GO_SCRIPT" "$TEST_GO_SCRIPTS_RELATIVE_DIR/foo.d"
  assert_success

  assert_line_equals 0 "LONGEST NAME LEN: ${#longest_name}"
  assert_line_equals 1 "COMMAND_NAMES: ${subcommands[*]}"
  assert_command_scripts_equal "${subcommands[@]/#/scripts/foo.d/}"
}

@test "$SUITE: find returns error if no commands are found" {
  mkdir "$TEST_GO_SCRIPTS_DIR/foo.d"
  run "$TEST_GO_SCRIPT" "$TEST_GO_SCRIPTS_RELATIVE_DIR/foo.d"
  assert_failure ''
}
