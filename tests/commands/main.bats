#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper
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
  local IFS=$'\n'
  assert_success "${flags[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 0 --
  local flags=('--paths' '--summaries')
  assert_success "${flags[*]}"

  run "$TEST_GO_SCRIPT" commands --complete 0 --p
  local flags=('--paths')
  assert_success '--paths'

  run "$TEST_GO_SCRIPT" commands --complete 1 --paths
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

  mkdir "$TEST_GO_SCRIPTS_DIR/"{bar,baz,foo}.d
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/bar.d/child0"
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/baz.d/child1"
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/foo.d/child2"
  chmod 700 "$TEST_GO_SCRIPTS_DIR/"{bar,baz,foo}.d/*
  mkdir "$TEST_GO_SCRIPTS_DIR/plugins/"{plugh,quux,xyzzy}.d
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/plugins/plugh.d/child3"
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/plugins/quux.d/child4"
  echo '#!' > "$TEST_GO_SCRIPTS_DIR/plugins/xyzzy.d/child5"
  chmod 700 "$TEST_GO_SCRIPTS_DIR/plugins/"{plugh,quux,xyzzy}.d/*

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
  local cmd_dir="$1"
  local cmd_name="$2"
  local cmd_path="$cmd_dir/$cmd_name"

  printf '#!\n#\n# Does %s stuff\n' "$cmd_name" > "$cmd_path"
  chmod 700 "$cmd_path"
}

@test "$SUITE: command summaries" {
  local user_commands=('bar' 'baz' 'foo')

  for cmd_name in "${user_commands[@]}"; do
    create_script_with_description "$TEST_GO_SCRIPTS_DIR" "$cmd_name"
  done

  run "$TEST_GO_SCRIPT" commands --summaries "$TEST_GO_SCRIPTS_DIR"
  local IFS=$'\n'
  local expected=(
    '  bar  Does bar stuff' '  baz  Does baz stuff' '  foo  Does foo stuff')
  assert_success "${expected[*]}"
}

@test "$SUITE: subcommand list, paths, and summaries" {
  local top_level_commands=('bar' 'baz' 'foo')
  local subcommands=('plugh' 'quux' 'xyzzy')
  local cmd_name
  local subcmd_dir
  local subcmd_name

  for cmd_name in "${top_level_commands[@]}"; do
    create_script_with_description "$TEST_GO_SCRIPTS_DIR" "$cmd_name"
    subcmd_dir="$TEST_GO_SCRIPTS_DIR/$cmd_name.d"
    mkdir "$subcmd_dir"

    for subcmd_name in "${subcommands[@]}"; do
      create_script_with_description "$subcmd_dir" "$subcmd_name"
    done
  done

  run "$TEST_GO_SCRIPT" commands 'foo'
  local IFS=$'\n'
  assert_success "${subcommands[*]}"

  local __all_scripts=(
    'scripts/foo.d/plugh' 'scripts/foo.d/quux' 'scripts/foo.d/xyzzy')
  local __expected_paths=()
  generate_expected_paths

  run "$TEST_GO_SCRIPT" commands --paths 'foo'
  assert_success "${__expected_paths[*]}"

  local expected_summaries=(
    '  plugh  Does plugh stuff'
    '  quux   Does quux stuff'
    '  xyzzy  Does xyzzy stuff')
  run "$TEST_GO_SCRIPT" commands --summaries 'foo'
  assert_success "${expected_summaries[*]}"
}
