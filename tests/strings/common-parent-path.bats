#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  test_filter
  create_strings_test_script 'declare parent' \
    '@go.common_parent_path "parent" "$@"' \
    'printf -- "%s\n" "$parent"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: empty argument list produces empty string" {
  run "$TEST_GO_SCRIPT"
  assert_success
}

@test "$SUITE: empty string produces empty string" {
  run "$TEST_GO_SCRIPT" ''
  assert_success
}

@test "$SUITE: single string returns empty string" {
  run "$TEST_GO_SCRIPT" 'foo/bar/baz'
  assert_success ''
}

@test "$SUITE: multiple paths with no common prefix returns empty string" {
  run "$TEST_GO_SCRIPT" 'foobar/baz' 'foobaz/quux' 'fooquux/xyzzy'
  assert_success ''
}

@test "$SUITE: multiple absolute paths with only root dir in common" {
  run "$TEST_GO_SCRIPT" '/foobar/baz' '/foobaz/quux' '/fooquux/xyzzy'
  assert_success '/'
}

@test "$SUITE: multiple paths with common parent path" {
  run "$TEST_GO_SCRIPT" 'foo/bar/baz' 'foo/bar/quux/xyzzy' 'foo/baz/plugh'
  assert_success 'foo/'
}
