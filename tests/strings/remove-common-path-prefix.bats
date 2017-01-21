#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  test_filter
  create_strings_test_script 'declare result=()' \
    '@go.remove_common_path_prefix "result" "$@"' \
    'printf -- "%s\n" "${result[@]}"'
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

@test "$SUITE: single string returns original string" {
  run "$TEST_GO_SCRIPT" 'foo/bar/baz'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: multiple paths with no common prefix returns original paths" {
  local paths=('foobar/baz'
    'foobaz/quux'
    'fooquux/xyzzy')
  run "$TEST_GO_SCRIPT" "${paths[@]}"
  assert_success "${paths[@]}"
}

@test "$SUITE: multiple absolute paths with only root dir in common" {
  run "$TEST_GO_SCRIPT" '/foobar/baz' \
    '/foobaz/quux' \
    '/fooquux/xyzzy'
  assert_success 'foobar/baz' \
    'foobaz/quux' \
    'fooquux/xyzzy'
}

@test "$SUITE: multiple paths with common path prefix returns suffixes" {
  run "$TEST_GO_SCRIPT" 'foo/bar/baz' \
    'foo/bar/quux/xyzzy' \
    'foo/baz/plugh'
  assert_success 'bar/baz'\
    'bar/quux/xyzzy' \
    'baz/plugh'
}
