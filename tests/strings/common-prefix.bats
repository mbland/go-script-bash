#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  test_filter
  create_strings_test_script 'declare prefix' \
    '@go.common_prefix "prefix" "$@"' \
    'printf -- "%s\n" "$prefix"'
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
  run "$TEST_GO_SCRIPT" 'foo'
  assert_success ''
}

@test "$SUITE: multiple strings with no common prefix returns empty string" {
  run "$TEST_GO_SCRIPT" 'foo' 'bar' 'baz'
  assert_success ''
}

@test "$SUITE: multiple strings with common prefix returns prefix substring" {
  run "$TEST_GO_SCRIPT" 'bar' 'baz' 'baxter'
  assert_success 'ba'
}
