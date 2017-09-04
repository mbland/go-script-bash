#! /usr/bin/env bats

load ../environment

LHS_DIR=
RHS_DIR=

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "diff"' \
    '@go.diff_directories "$@"'

  LHS_DIR="$TEST_GO_ROOTDIR/lhs"
  RHS_DIR="$TEST_GO_ROOTDIR/rhs"
  mkdir -p "$LHS_DIR" "$RHS_DIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: warns if LHS dir doesn't exist" {
  local lhs="$LHS_DIR"
  rmdir "$lhs"
  run "$TEST_GO_SCRIPT" "$lhs" "$RHS_DIR"
  assert_failure
  assert_output_matches \
    "WARN.* Left-hand side directory $lhs doesn't exist or isn't a directory"
}

@test "$SUITE: warns if RHS dir doesn't exist" {
  local rhs="$RHS_DIR"
  rmdir "$rhs"
  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$rhs"
  assert_failure
  assert_output_matches \
    "WARN.* Right-hand side directory $rhs doesn't exist or isn't a directory"
}

@test "$SUITE: does nothing if first directory empty" {
  printf '%s\n' 'foo' >"$RHS_DIR/foo"
  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$RHS_DIR"
  assert_success ''
}

@test "$SUITE: returns success if directories contain the same single file" {
  skip_if_system_missing 'diff'
  printf '%s\n' 'foo' >"$LHS_DIR/foo"
  printf '%s\n' 'foo' >"$RHS_DIR/foo"
  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$RHS_DIR"
  assert_success ''
}

@test "$SUITE: returns success if rhs contains more files" {
  skip_if_system_missing 'diff'
  printf '%s\n' 'foo' >"$LHS_DIR/foo"
  printf '%s\n' 'foo' >"$RHS_DIR/foo"
  printf '%s\n' 'bar' >"$RHS_DIR/bar"
  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$RHS_DIR"
  assert_success ''
}

@test "$SUITE: returns an error if rhs contains fewer files" {
  skip_if_system_missing 'diff'
  local missing="$RHS_DIR/bar"

  printf '%s\n' 'foo' >"$LHS_DIR/foo"
  printf '%s\n' 'bar' >"$LHS_DIR/bar"
  printf '%s\n' 'foo' >"$RHS_DIR/foo"

  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$RHS_DIR"
  assert_failure
  assert_output_matches \
    "WARN.* Right-hand side file $missing doesn't exist or isn't a regular file"
}

@test "$SUITE: warns and returns an error when files differ" {
  skip_if_system_missing 'diff'

  printf '%s\n' 'foo' >"$LHS_DIR/foo"
  printf '%s\n' 'bar' >"$RHS_DIR/foo"

  run "$TEST_GO_SCRIPT" "$LHS_DIR" "$RHS_DIR"
  assert_failure
  assert_output_matches "WARN.* $LHS_DIR/foo differs from $RHS_DIR/foo"
}

@test "$SUITE: --edit opens _GO_DIFF_EDITOR when files differ" {
  skip_if_system_missing 'diff'

  printf '%s\n' 'foo' >"$LHS_DIR/foo"
  printf '%s\n' 'bar' >"$RHS_DIR/foo"

  stub_program_in_path 'vimdiff' \
    'printf "%s\n" "LHS: $1" "RHS: $2"'

  _GO_DIFF_EDITOR='vimdiff' run "$TEST_GO_SCRIPT" --edit "$LHS_DIR" "$RHS_DIR"
  restore_program_in_path 'vimdiff'

  assert_failure
  assert_lines_match \
    "WARN.* $LHS_DIR/foo differs from $RHS_DIR/foo" \
    "INFO.* Editing $LHS_DIR/foo and $RHS_DIR/foo" \
    "LHS: $LHS_DIR/foo" \
    "RHS: $RHS_DIR/foo"
}
