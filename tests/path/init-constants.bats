#! /usr/bin/env bats

load ../environment

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
  run "$TEST_GO_SCRIPT"
  assert_success

  local expected_paths=("$_GO_ROOTDIR/libexec" "$TEST_GO_SCRIPTS_DIR")

  assert_line_equals 0 '_GO_PLUGINS_DIR: '
  assert_line_equals 1 '_GO_PLUGINS_PATHS: '
  assert_line_equals 2 "_GO_SEARCH_PATHS: ${expected_paths[*]}"
}

@test "$SUITE: initialize constants with plugin bindirs" {
  local plugin_bindirs=(
    "$TEST_GO_PLUGINS_DIR/plugin0/bin"
    "$TEST_GO_PLUGINS_DIR/plugin1/bin"
    "$TEST_GO_PLUGINS_DIR/plugin2/bin")
  mkdir -p "${plugin_bindirs[@]}"

  run "$TEST_GO_SCRIPT"
  assert_success

  local expected_paths=(
    "$_GO_ROOTDIR/libexec"
    "$TEST_GO_PLUGINS_DIR"
    "${plugin_bindirs[@]}"
    "$TEST_GO_SCRIPTS_DIR")

  assert_line_equals 0 "_GO_PLUGINS_DIR: $TEST_GO_PLUGINS_DIR"
  assert_line_equals 1 \
    "_GO_PLUGINS_PATHS: $TEST_GO_PLUGINS_DIR ${plugin_bindirs[*]}"
  assert_line_equals 2 "_GO_SEARCH_PATHS: ${expected_paths[*]}"
}
