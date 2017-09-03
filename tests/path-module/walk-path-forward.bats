#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/path"

setup() {
  test_filter
}

teardown() {
  @go.remove_test_go_rootdir
}

run_walk_path_forward() {
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
    '@go.walk_path_forward walk_callback "$1"' \
    'RESULT="$?"' \
    'printf "%s\n" "${WALKED[@]}"' \
    'exit "$RESULT"'
  run "$TEST_GO_SCRIPT" "$1"
}

@test "$SUITE: empty path" {
  run_walk_path_forward
  assert_success ''
}

@test "$SUITE: root path" {
  run_walk_path_forward '/'
  assert_success '/'
}

@test "$SUITE: absolute path" {
  run_walk_path_forward '/foo/bar/baz'
  assert_success \
    '/' \
    '/foo' \
    '/foo/bar' \
    '/foo/bar/baz'
}

@test "$SUITE: relative path" {
  run_walk_path_forward 'foo/bar/baz'
  assert_success \
    'foo' \
    'foo/bar' \
    'foo/bar/baz'
}

@test "$SUITE: stop walking and return nonzero when operation returns nonzero" {
  STOP_PATH='foo/bar' run_walk_path_forward 'foo/bar/baz'
  assert_failure \
    'foo' \
    'foo/bar'
}

@test "$SUITE: path with adjacent slashes" {
  run_walk_path_forward '/foo//bar///baz////'
  assert_success \
    '/' \
    '/foo' \
    '/foo//' \
    '/foo//bar' \
    '/foo//bar//' \
    '/foo//bar///' \
    '/foo//bar///baz' \
    '/foo//bar///baz//' \
    '/foo//bar///baz///' \
    '/foo//bar///baz////'
}
