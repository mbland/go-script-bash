#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "path"' \
    'declare result' \
    '@go.add_parent_dir_if_relative_path "$@"' \
    'printf "%s\n" "$result"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: converts a relative path to an absolute path based on PWD" {
  run "$TEST_GO_SCRIPT" 'result' 'foo'
  assert_success "$TEST_GO_ROOTDIR/foo"
}

@test "$SUITE: adds a parent to a relative path" {
  run "$TEST_GO_SCRIPT" --parent 'foo' 'result' 'bar'
  assert_success 'foo/bar'
}

@test "$SUITE: leaves an absolute path unmodified" {
  run "$TEST_GO_SCRIPT" --parent 'foo' 'result' '/bar/baz'
  assert_success '/bar/baz'
}
