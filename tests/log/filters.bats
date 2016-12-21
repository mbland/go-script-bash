#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

run_log_script_and_assert_success() {
  set +o functrace
  local result=0

  run_log_script "$@" \
    '@go.log DEBUG  debug 0' \
    '@go.log START  testing filter' \
    '@go.log DEBUG  debug 1' \
    '@go.log RUN    echo Hello, World!' \
    '@go.log INFO   Hello, World!' \
    '@go.log DEBUG  debug 2' \
    '@go.log FINISH testing filter' \
    '@go.log DEBUG  debug 3' \
    '@go.log INFO   Goodbye, World!'

  if ! assert_success; then
    result=1
  fi
  set +o functrace
  return_from_bats_assertion "$BASH_SOURCE" "$result"
}

@test "$SUITE: default _GO_LOG_LEVEL_FILTER is RUN" {
  run_log_script_and_assert_success
  assert_log_equals \
    START  'testing filter' \
    RUN    'echo Hello, World!' \
    INFO   'Hello, World!' \
    FINISH 'testing filter' \
    INFO   'Goodbye, World!'
}

@test "$SUITE: set _GO_LOG_LEVEL_FILTER to DEBUG" {
  _GO_LOG_LEVEL_FILTER='DEBUG' run_log_script_and_assert_success
  assert_log_equals \
    DEBUG  'debug 0' \
    START  'testing filter' \
    DEBUG  'debug 1' \
    RUN    'echo Hello, World!' \
    INFO   'Hello, World!' \
    DEBUG  'debug 2' \
    FINISH 'testing filter' \
    DEBUG  'debug 3' \
    INFO   'Goodbye, World!'
}

@test "$SUITE: set _GO_LOG_LEVEL_FILTER to INFO" {
  _GO_LOG_LEVEL_FILTER='INFO' run_log_script_and_assert_success
  assert_log_equals \
    INFO   'Hello, World!' \
    INFO   'Goodbye, World!'
}

@test "$SUITE: error if _GO_LOG_LEVEL_FILTER doesn't match a valid level" {
  _GO_LOG_LEVEL_FILTER='FOOBAR' run_log_script '@go.log FOOBAR fubarred'
  assert_failure
  assert_log_equals \
    FATAL 'Invalid _GO_LOG_LEVEL_FILTER: FOOBAR' \
    "  $TEST_GO_SCRIPT:4 main"
}

@test "$SUITE: error if _GO_LOG_CONSOLE_FILTER doesn't match a valid level" {
  _GO_LOG_CONSOLE_FILTER='FOOBAR' run_log_script '@go.log FOOBAR fubarred'
  assert_failure
  assert_log_equals \
    FATAL 'Invalid _GO_LOG_CONSOLE_FILTER: FOOBAR' \
    "  $TEST_GO_SCRIPT:4 main"
}

@test "$SUITE: _GO_LOG_CONSOLE_FILTER lower priority override" {
  _GO_LOG_CONSOLE_FILTER='DEBUG' run_log_script_and_assert_success \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log'"

  assert_log_equals \
    DEBUG  'debug 0' \
    START  'testing filter' \
    DEBUG  'debug 1' \
    RUN    'echo Hello, World!' \
    INFO   'Hello, World!' \
    DEBUG  'debug 2' \
    FINISH 'testing filter' \
    DEBUG  'debug 3' \
    INFO   'Goodbye, World!'

  assert_log_file_equals "$TEST_GO_ROOTDIR/info.log" \
    START  'testing filter' \
    RUN    'echo Hello, World!' \
    INFO   'Hello, World!' \
    FINISH 'testing filter' \
    INFO   'Goodbye, World!'
}

@test "$SUITE: _GO_LOG_CONSOLE_FILTER higher priority override" {
  _GO_LOG_CONSOLE_FILTER='INFO' run_log_script_and_assert_success \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log'"

  assert_log_equals \
    INFO   'Hello, World!' \
    INFO   'Goodbye, World!'

  assert_log_file_equals "$TEST_GO_ROOTDIR/info.log" \
    START  'testing filter' \
    RUN    'echo Hello, World!' \
    INFO   'Hello, World!' \
    FINISH 'testing filter' \
    INFO   'Goodbye, World!'
}
