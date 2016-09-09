#! /usr/bin/env bats

load environment
load assertions
load script_helper
load commands/helpers

setup() {
  create_test_go_script '@go "$@"'
  find_builtins
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: all top-level commands for zeroth or first argument" {
  # user_commands and plugin_commands must remain hand-sorted.
  local user_commands=('bar' 'baz' 'foo')
  local plugin_commands=('plugh' 'quux' 'xyzzy')
  local __all_scripts=("${BUILTIN_SCRIPTS[@]}")

  add_scripts "$TEST_GO_SCRIPTS_DIR" "${user_commands[@]}"
  add_scripts "$TEST_GO_SCRIPTS_DIR/plugins" "${plugin_commands[@]}"

  # Aliases will get printed before all other commands.
  __all_scripts=("$(./go 'aliases')" "${__all_scripts[@]}")

  run "$TEST_GO_SCRIPT" complete 0
  local IFS=$'\n'
  assert_success "${__all_scripts[*]##*/}"

  run "$TEST_GO_SCRIPT" complete 0 xyz
  assert_success 'xyzzy'

  run "$TEST_GO_SCRIPT" complete 0 xyzzy-not
  assert_failure ''
}

@test "$SUITE: cd and pushd" {
  local subdirs=('bar' 'baz' 'foo')
  local files=('plugh' 'quux' 'xyzzy')
  mkdir -p "${subdirs[@]/#/$TEST_GO_SCRIPTS_DIR/}"
  touch "${files[@]/#/$TEST_GO_SCRIPTS_DIR/}"

  run "$TEST_GO_SCRIPT" complete 1 cd ''
  assert_success 'scripts'
  run "$TEST_GO_SCRIPT" complete 1 pushd ''
  assert_success 'scripts'

  run "$TEST_GO_SCRIPT" complete 1 cd 'scripts/'
  local IFS=$'\n'
  assert_success "${subdirs[*]/#/scripts/}"
  run "$TEST_GO_SCRIPT" complete 1 pushd 'scripts/'
  assert_success "${subdirs[*]/#/scripts/}"
}

@test "$SUITE: edit and run" {
  local subdirs=('bar' 'baz' 'foo')
  local files=('plugh' 'quux' 'xyzzy')
  mkdir -p "${subdirs[@]/#/$TEST_GO_SCRIPTS_DIR/}"
  touch "${files[@]/#/$TEST_GO_SCRIPTS_DIR/}"

  local top_level=('go' 'scripts')

  run "$TEST_GO_SCRIPT" complete 1 edit ''
  local IFS=$'\n'
  assert_success "${top_level[*]}"
  run "$TEST_GO_SCRIPT" complete 1 run ''
  assert_success "${top_level[*]}"

  local all_scripts_entries=("${subdirs[@]}" "${files[@]}")

  run "$TEST_GO_SCRIPT" complete 1 edit 'scripts/'
  assert_success "${all_scripts_entries[*]/#/scripts/}"
  run "$TEST_GO_SCRIPT" complete 1 run 'scripts/'
  assert_success "${all_scripts_entries[*]/#/scripts/}"
}
