#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: error if result array name not a valid identifier" {
  create_strings_test_script '@go.split "," "foo,bar,baz" "invalid;"'
  run "$TEST_GO_SCRIPT"
  assert_failure

  local err_msg='^Result array name "invalid;" for @go.split '
  err_msg+='contains invalid identifier characters at:$'
  assert_lines_match "$err_msg" \
    "^  $TEST_GO_SCRIPT:[0-9] main$"
}

@test "$SUITE: empty string" {
  create_strings_test_script 'declare result=()' \
    '@go.split "," "" "result"' \
    'echo "${result[@]}"'
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: single item" {
  create_strings_test_script 'declare result=()' \
    '@go.split "," "foo" "result"' \
    'echo "${result[@]}"'
  run "$TEST_GO_SCRIPT"
  assert_success 'foo'
}

@test "$SUITE: multiple items" {
  create_strings_test_script 'declare result=()' \
    '@go.split "," "foo,bar,baz" "result"' \
    'echo "${result[@]}"'
  run "$TEST_GO_SCRIPT"
  assert_success 'foo bar baz'
}

@test "$SUITE: split items into same variable" {
  create_strings_test_script 'declare items="foo,bar,baz"' \
    '@go.split "," "$items" "items"' \
    'echo "${items[@]}"'
  run "$TEST_GO_SCRIPT"
  assert_success 'foo bar baz'
}
