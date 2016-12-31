#! /usr/bin/env bats

load environment

setup() {
  create_test_go_script '. "$_GO_USE_MODULES" "validation"' \
    '@go.validate_input "$@"'
}

teardown() {
  remove_test_go_rootdir
}

assert_error_on_invalid_input() {
  set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"
  run "$TEST_GO_SCRIPT" "$1"

  if [[ "$status" -eq '0' ]]; then
    echo "Expected input to fail validation: $1" >&2
    return_from_bats_assertion 1
  else
    return_from_bats_assertion
  fi
}

assert_success_on_valid_input() {
  set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"
  run "$TEST_GO_SCRIPT" "$1"

  if [[ "$status" -ne '0' ]]; then
    echo "Expected input to pass validation: $1" >&2
    return_from_bats_assertion 1
  else
    return_from_bats_assertion
  fi
}

@test "$SUITE: returns error on invalid input" {
  assert_error_on_invalid_input 'foo`bar'
  assert_error_on_invalid_input 'foo"bar'
  assert_error_on_invalid_input 'foo;bar'
  assert_error_on_invalid_input 'foo$bar'
  assert_error_on_invalid_input 'foo(bar'
  assert_error_on_invalid_input 'foo)bar'
  assert_error_on_invalid_input 'foo&bar'
  assert_error_on_invalid_input 'foo|bar'
  assert_error_on_invalid_input 'foo<bar'
  assert_error_on_invalid_input 'foo>bar'
  assert_error_on_invalid_input 'foo'$'\n''bar'
  assert_error_on_invalid_input 'foo'$'\r''bar'
  assert_error_on_invalid_input "\`echo SURPRISE >&2\`$FILE_PATH"
  assert_error_on_invalid_input "$FILE_PATH\"; echo 'SURPRISE'"
}

@test "$SUITE: returns success on valid input" {
  assert_success_on_valid_input 'foobar'
  assert_success_on_valid_input 'foo\`bar'
  assert_success_on_valid_input 'foo\"bar'
  assert_success_on_valid_input 'foo\;bar'
  assert_success_on_valid_input 'foo\$bar'
  assert_success_on_valid_input 'foo\(bar'
  assert_success_on_valid_input 'foo\)bar'
  assert_success_on_valid_input 'foo\&bar'
  assert_success_on_valid_input 'foo\|bar'
  assert_success_on_valid_input 'foo\<bar'
  assert_success_on_valid_input 'foo\>bar'
  assert_success_on_valid_input "foo\\'\\\$\\'\n''bar"
  assert_success_on_valid_input "foo\\'\\\$\\'\r''bar"
  assert_success_on_valid_input '\`echo SURPRISE \>\&2\`\$FILE_PATH'
  assert_success_on_valid_input "\\\$FILE_PATH\\\"\\; echo 'SURPRISE'"
}
