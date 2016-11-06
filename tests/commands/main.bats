#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  create_test_go_script '@go "$@"'
  find_builtins

  # We have to add back the _GO_ROOTDIR that was stripped from the beginning of
  # each element of BUILTIN_SCRIPTS, because it will be different from the
  # _GO_ROOTDIR of the generated test script. Thus, `$TEST_GO_SCRIPT commands`
  # will report builtin command paths as absolute.
  BUILTIN_SCRIPTS=("${BUILTIN_SCRIPTS[@]/#/$_GO_ROOTDIR/}")
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: tab completions" {
  run "$TEST_GO_SCRIPT" commands --complete 0
  local flags=('--paths' '--summaries')
  local expected=("${flags[@]}" "${BUILTIN_CMDS[@]}")
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 0 --
  local flags=('--paths' '--summaries')
  assert_success "${flags[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 0 --p
  local flags=('--paths')
  assert_success '--paths'

  run "$TEST_GO_SCRIPT" commands --complete 0 --foo
  assert_failure

  run "$TEST_GO_SCRIPT" commands --complete 1 --paths
  assert_success "${BUILTIN_CMDS[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 1 --summaries
  assert_success "${BUILTIN_CMDS[*]}"
}

@test "$SUITE: no tab completions for or after search paths" {
  run "$TEST_GO_SCRIPT" commands --complete 0 "$TEST_GO_SCRIPTS_DIR"
  assert_failure

  run "$TEST_GO_SCRIPT" commands --complete 1 "$TEST_GO_SCRIPTS_DIR"
  assert_failure
}

@test "$SUITE: tab complete subcommand" {
  create_test_command_script 'foo'
  mkdir "$TEST_GO_SCRIPTS_DIR/foo.d"

  local expected=('bar' 'baz' 'quux')
  local subcommand

  for subcommand in "${expected[@]}"; do
    create_test_command_script "foo.d/$subcommand"
  done

  run "$TEST_GO_SCRIPT" commands --complete 1 foo
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 1 foo b
  expected=('bar' 'baz')
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 1 foo g
  assert_failure

  run "$TEST_GO_SCRIPT" commands --complete 2 foo bar
  assert_failure
}

@test "$SUITE: only tab complete flags before other args" {
  create_test_command_script 'foo'
  mkdir "$TEST_GO_SCRIPTS_DIR/foo.d"

  local subcommands=('bar' 'baz' 'quux')
  local subcommand

  for subcommand in "${subcommands[@]}"; do
    create_test_command_script "foo.d/$subcommand"
  done

  run "$TEST_GO_SCRIPT" commands --complete 0 '' foo
  expected=('--paths' '--summaries')
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 1 foo '' bar
  assert_failure
}

@test "$SUITE: error if unknown flag specified" {
  run "$TEST_GO_SCRIPT" commands --foobar
  assert_failure 'Unknown option: --foobar'
}

@test "$SUITE: error if search path does not exist" {
  run "$TEST_GO_SCRIPT" commands "$TEST_GO_SCRIPTS_DIR:foo/bar"
  assert_failure "Command search path foo/bar does not exist."
}

@test "$SUITE: error if any arguments after search path" {
  run "$TEST_GO_SCRIPT" commands "$TEST_GO_SCRIPTS_DIR" foo bar
  assert_failure "Cannot specify any arguments after search paths."
}

@test "$SUITE: error if command is a shell alias" {
  run "$TEST_GO_SCRIPT" commands ls
  assert_failure 'ls is a shell alias.'
}

@test "$SUITE: error if command does not exist" {
  run "$TEST_GO_SCRIPT" commands foo
  assert_failure
  assert_line_equals 0 'Unknown command: foo'
}

@test "$SUITE: error if no commands found" {
  run "$TEST_GO_SCRIPT" commands "$TEST_GO_SCRIPTS_DIR"
  assert_failure ''
}

@test "$SUITE: list top-level builtins, plugins, and scripts by default" {
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' 'xyzzy')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"

  local cmd_name

  mkdir "$TEST_GO_SCRIPTS_DIR/"{bar,baz,foo}.d
  create_test_command_script 'bar.d/child0'
  create_test_command_script 'baz.d/child1'
  create_test_command_script 'foo.d/child2'
  mkdir "$TEST_GO_SCRIPTS_DIR/plugins/"{plugh,quux,xyzzy}.d
  create_test_command_script 'plugins/plugh.d/child3'
  create_test_command_script 'plugins/quux.d/child4'
  create_test_command_script 'plugins/xyzzy.d/child5'

  run "$TEST_GO_SCRIPT" commands
  local IFS=$'\n'
  assert_success "${__all_scripts[*]##*/}"
}

@test "$SUITE: specify plugins and user search paths, omit builtins" {
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' 'xyzzy')
  local __all_scripts=()

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"
  local IFS=':'
  local search_paths=("$TEST_GO_SCRIPTS_DIR/plugins" "$TEST_GO_SCRIPTS_DIR")

  run "$TEST_GO_SCRIPT" commands "${search_paths[*]}"
  IFS=$'\n'
  assert_success "${__all_scripts[*]##*/}"
}

generate_expected_paths() {
  local script
  local cmd_name
  local longest_cmd_name_len
  for cmd_script in "${__all_scripts[@]}"; do
    cmd_name="${cmd_script##*/}"
    if [[ "${#cmd_name}" -gt "$longest_cmd_name_len" ]]; then
      longest_cmd_name_len="${#cmd_name}"
    fi
  done

  for script in "${__all_scripts[@]}"; do
    cmd_name="${script##*/}"
    __expected_paths+=("$(printf "%-${longest_cmd_name_len}s  %s" \
      "$cmd_name" "$script")")
  done
}

@test "$SUITE: command paths" {
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' 'xyzzy')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"

  local __expected_paths=()
  generate_expected_paths

  run "$TEST_GO_SCRIPT" commands --paths
  local IFS=$'\n'
  assert_success "${__expected_paths[*]}"
}

create_script_with_description() {
  local script_path="$1"
  local cmd_name="${script_path##*/}"

  create_test_command_script "$script_path" \
    '#' \
    "# Does $cmd_name stuff"
}

@test "$SUITE: command summaries" {
  local user_commands=('bar' 'baz' 'foo')

  for cmd_name in "${user_commands[@]}"; do
    create_script_with_description "$cmd_name"
  done

  run "$TEST_GO_SCRIPT" commands --summaries "$TEST_GO_SCRIPTS_DIR"
  local IFS=$'\n'
  local expected=(
    '  bar  Does bar stuff'
    '  baz  Does baz stuff'
    '  foo  Does foo stuff')
  assert_success "${expected[*]}"
}

@test "$SUITE: subcommand list, paths, and summaries" {
  local top_level_commands=('bar' 'baz' 'foo')
  local subcommands=('plugh' 'quux' 'xyzzy')
  local cmd_name
  local subcmd_dir
  local subcmd_name

  for cmd_name in "${top_level_commands[@]}"; do
    create_script_with_description "$cmd_name"
    subcmd_dir="$TEST_GO_SCRIPTS_DIR/$cmd_name.d"
    mkdir "$subcmd_dir"

    for subcmd_name in "${subcommands[@]}"; do
      create_script_with_description "$cmd_name.d/$subcmd_name"
    done
  done

  run "$TEST_GO_SCRIPT" commands 'foo'
  local IFS=$'\n'
  assert_success "${subcommands[*]}"

  local expected_paths=(
    'plugh  scripts/foo.d/plugh'
    'quux   scripts/foo.d/quux'
    'xyzzy  scripts/foo.d/xyzzy')

  run "$TEST_GO_SCRIPT" commands --paths 'foo'
  assert_success "${expected_paths[*]}"

  local expected_summaries=(
    '  plugh  Does plugh stuff'
    '  quux   Does quux stuff'
    '  xyzzy  Does xyzzy stuff')
  run "$TEST_GO_SCRIPT" commands --summaries 'foo'
  assert_success "${expected_summaries[*]}"
}
