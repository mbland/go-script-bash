#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
}

teardown() {
  remove_bats_test_dirs
}

@test "$SUITE: error if argument not a positive integer" {
  local err_msg='The argument to test_break_after_num_iterations '
  err_msg+='must be a positive integer at:'

  local top_stack_line="/bats-exec-test:[0-9]+ run"

  run test_break_after_num_iterations
  assert_failure
  assert_line_equals 0 "$err_msg"
  assert_line_matches 1 "$top_stack_line"

  run test_break_after_num_iterations 0
  assert_failure
  assert_line_equals 0 "$err_msg"
  assert_line_matches 1 "$top_stack_line"

  run test_break_after_num_iterations -1
  assert_failure
  assert_line_equals 0 "$err_msg"
  assert_line_matches 1 "$top_stack_line"

  run test_break_after_num_iterations 2foobar7
  assert_failure
  assert_line_equals 0 "$err_msg"
  assert_line_matches 1 "$top_stack_line"
}

@test "$SUITE: break after specified number of iterations" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  test_break_after_num_iterations "$1"' \
    'done'
  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 5
  assert_failure 'Breaking after iteration 5 at:' \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:3 main"
}

@test "$SUITE: does nothing if count not reached" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  test_break_after_num_iterations "$1"' \
    'done'
  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 6
  assert_success ''
}

@test "$SUITE: does nothing if TEST_DEBUG is null" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  test_break_after_num_iterations "$1"' \
    'done'
  TEST_DEBUG= run "$BATS_TEST_ROOTDIR/test-break-after-n" 5
  assert_success ''
}

@test "$SUITE: break after recursive calls" {
  create_bats_test_script 'test-break-after-n' \
    'recursive_func() {' \
    '  test_break_after_num_iterations "$N"' \
    '  recursive_func' \
    '}' \
    'N="$1"' \
    'recursive_func'
  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 3
  assert_failure 'Breaking after iteration 3 at:' \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:3 recursive_func" \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:4 recursive_func" \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:4 recursive_func" \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:7 main"
}

@test "$SUITE: counts isolated between lines in same file" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  test_break_after_num_iterations "$(($1+1))"' \
    '  test_break_after_num_iterations "$1"' \
    'done'
  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 5
  assert_failure 'Breaking after iteration 5 at:' \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:4 main"
}

@test "$SUITE: counts isolated across files" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  . "${BASH_SOURCE[0]%/*}/foo"' \
    '  . "${BASH_SOURCE[0]%/*}/bar"' \
    'done'
  create_bats_test_script 'foo' \
    '  test_break_after_num_iterations "$(($1+1))"'
  create_bats_test_script 'bar' \
    '  test_break_after_num_iterations "$1"'

  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 5
  assert_failure 'Breaking after iteration 5 at:' \
    "  $BATS_TEST_ROOTDIR/bar:2 source" \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:4 main"
}

@test "$SUITE: prints values of variables on break" {
  create_bats_test_script 'test-break-after-n' \
    'for ((i=0; i != 5; ++i)); do' \
    '  test_break_after_num_iterations "$@"' \
    'done'

  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-break-after-n" 5 \
    'BASH_SOURCE[1]' 'BASH_LINENO[0]' 'FUNCNAME[1]' 'i'
  assert_failure 'Breaking after iteration 5 at:' \
    "  $BATS_TEST_ROOTDIR/test-break-after-n:3 main" \
    "BASH_SOURCE[1]: $BATS_TEST_ROOTDIR/test-break-after-n" \
    'BASH_LINENO[0]: 3' \
    'FUNCNAME[1]: main' \
    'i: 4'
}
