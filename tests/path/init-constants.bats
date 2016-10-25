#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

setup() {
  create_test_go_script \
    '. "$_GO_CORE_DIR/lib/internal/path"' \
    'echo "_GO_PLUGINS_DIR: $_GO_PLUGINS_DIR"' \
    'echo "_GO_PLUGINS_PATHS: ${_GO_PLUGINS_PATHS[@]}"' \
    'echo "_GO_SEARCH_PATHS: ${_GO_SEARCH_PATHS[@]}"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: initialize constants without plugins" {
  run "$TEST_GO_SCRIPT"
  assert_success

  local expected_paths=("$_GO_ROOTDIR/libexec" "$TEST_GO_SCRIPTS_DIR")

  assert_line_equals 0 '_GO_PLUGINS_DIR: '
  assert_line_equals 1 '_GO_PLUGINS_PATHS: '
  assert_line_equals 2 "_GO_SEARCH_PATHS: ${expected_paths[*]}"
}

@test "$SUITE: initialize constants with plugins dir" {
  local plugins_dir="$TEST_GO_SCRIPTS_DIR/plugins"
  mkdir "$plugins_dir"
  run "$TEST_GO_SCRIPT"
  assert_success

  local expected_paths=(
    "$_GO_ROOTDIR/libexec" "$plugins_dir" "$TEST_GO_SCRIPTS_DIR")

  assert_line_equals 0 "_GO_PLUGINS_DIR: $plugins_dir"
  assert_line_equals 1 "_GO_PLUGINS_PATHS: $plugins_dir"
  assert_line_equals 2 "_GO_SEARCH_PATHS: ${expected_paths[*]}"
}

@test "$SUITE: initialize constants with plugin bindirs" {
  local plugins_dir="$TEST_GO_SCRIPTS_DIR/plugins"
  local plugin_bindirs=(
    "$plugins_dir/plugin0/bin"
    "$plugins_dir/plugin1/bin"
    "$plugins_dir/plugin2/bin")
  mkdir -p "${plugin_bindirs[@]}"

  run "$TEST_GO_SCRIPT"
  assert_success

  local expected_paths=(
    "$_GO_ROOTDIR/libexec"
    "$plugins_dir"
    "${plugin_bindirs[@]}"
    "$TEST_GO_SCRIPTS_DIR")

  assert_line_equals 0 "_GO_PLUGINS_DIR: $plugins_dir"
  assert_line_equals 1 "_GO_PLUGINS_PATHS: $plugins_dir ${plugin_bindirs[*]}"
  assert_line_equals 2 "_GO_SEARCH_PATHS: ${expected_paths[*]}"
}
