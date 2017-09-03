#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/path"

WALK_TEST_ROOT="$TEST_GO_ROOTDIR/walk-files-test"

setup() {
  test_filter
}

teardown() {
  @go.remove_test_go_rootdir
}

run_walk_file_system() {
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "path"' \
    'declare WALKED' \
    'WALKED=()' \
    'walk_callback() {' \
    '  WALKED+=("$1")' \
    '  if [[ "$1" == "$STOP_PATH" ]]; then' \
    '    return 1' \
    '  fi' \
    '}' \
    'if [[ "$1" == "--bfs" ]]; then' \
    '  @go.walk_file_system --bfs walk_callback "${@:2}"' \
    'else' \
    '  @go.walk_file_system walk_callback "$@"' \
    'fi' \
    'RESULT="$?"' \
    'printf "%s\n" "${WALKED[@]#$WALK_TEST_ROOT/}"' \
    'exit "$RESULT"'
  WALK_TEST_ROOT="$WALK_TEST_ROOT" run "$TEST_GO_SCRIPT" "$@"
}

create_walk_test_files() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  __create_walk_test_files "$@"
  restore_bats_shell_options
}

__create_walk_test_files() {
  local files=("${@/#/$WALK_TEST_ROOT/}")
  local dirs=("${files[@]%/*}")
  local current

  create_bats_test_dirs "${dirs[@]#$TEST_GO_ROOTDIR/}"

  for current in "${files[@]}"; do
    printf '%s\n' "${current##*/}" >"$current"
  done
}

@test "$SUITE: empty args" {
  run_walk_file_system
  assert_success ''
}

@test "$SUITE: empty path" {
  run_walk_file_system ''
  assert_success ''
}

@test "$SUITE: nonexistent file paths" {
  run_walk_file_system 'foo' 'bar' 'baz'
  assert_success ''
}

@test "$SUITE: walk from root" {
  create_walk_test_files 'foo/bar' 'baz' 'quux/xyzzy' 'quux/plugh'
  run_walk_file_system "$WALK_TEST_ROOT"
  assert_success \
    "$WALK_TEST_ROOT" \
    'baz' \
    'foo' \
    'foo/bar' \
    'quux' \
    'quux/plugh' \
    'quux/xyzzy'
}

@test "$SUITE: walk from root breadth-first" {
  create_walk_test_files 'foo/bar' 'baz' 'quux/xyzzy' 'quux/plugh'
  run_walk_file_system --bfs "$WALK_TEST_ROOT"
  assert_success \
    "$WALK_TEST_ROOT" \
    'baz' \
    'foo' \
    'quux' \
    'foo/bar' \
    'quux/plugh' \
    'quux/xyzzy'
}

@test "$SUITE: walk specific dirs and files" {
  create_walk_test_files 'foo/bar' 'baz' 'quux/xyzzy' 'quux/plugh'
  run_walk_file_system "$WALK_TEST_ROOT/foo" "$WALK_TEST_ROOT/quux/plugh"
  assert_success \
    'foo' \
    'foo/bar' \
    'quux/plugh'
}

@test "$SUITE: terminating depth-first search returns nonzero" {
  create_walk_test_files 'foo/bar' 'baz' 'quux/xyzzy' 'quux/plugh'
  STOP_PATH="$WALK_TEST_ROOT/foo/bar" run_walk_file_system "$WALK_TEST_ROOT"
  assert_failure \
    "$WALK_TEST_ROOT" \
    'baz' \
    'foo' \
    'foo/bar'
}

@test "$SUITE: terminating breadth-first search returns nonzero" {
  create_walk_test_files 'foo/bar' 'baz' 'quux/xyzzy' 'quux/plugh'
  STOP_PATH="$WALK_TEST_ROOT/foo/bar" \
    run_walk_file_system --bfs "$WALK_TEST_ROOT"
  assert_failure \
    "$WALK_TEST_ROOT" \
    'baz' \
    'foo' \
    'quux' \
    'foo/bar'
}
