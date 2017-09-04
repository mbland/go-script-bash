#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "diff"'\
    '@go.diff_files "$@"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: warns if lhs file doesn't exist or isn't regular" {
  local lhs="$TEST_GO_ROOTDIR/foo"

  run "$TEST_GO_SCRIPT" "$lhs"
  assert_failure
  assert_output_matches \
    "WARN.* Left-hand side file $lhs doesn't exist or isn't a regular file"
}

@test "$SUITE: warns if rhs file doesn't exist or isn't regular" {
  local lhs="$TEST_GO_ROOTDIR/foo"
  local rhs="$TEST_GO_ROOTDIR/bar"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf '%s\n' 'foo' >"$lhs"
  mkdir "$rhs"

  run "$TEST_GO_SCRIPT" "$lhs" "$rhs"
  assert_failure
  assert_output_matches \
    "WARN.* Right-hand side file $rhs doesn't exist or isn't a regular file"
}

@test "$SUITE: return success if the files match" {
  skip_if_system_missing 'diff'

  local lhs="$TEST_GO_ROOTDIR/foo"
  local rhs="$TEST_GO_ROOTDIR/bar"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf '%s\n' 'foo' >"$lhs"
  printf '%s\n' 'foo' >"$rhs"

  run "$TEST_GO_SCRIPT" "$lhs" "$rhs"
  assert_success ''
}

@test "$SUITE: warns and return failure if the files differ" {
  skip_if_system_missing 'diff'

  local lhs="$TEST_GO_ROOTDIR/foo"
  local rhs="$TEST_GO_ROOTDIR/bar"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf '%s\n' 'foo' >"$lhs"
  printf '%s\n' 'bar' >"$rhs"

  run "$TEST_GO_SCRIPT" "$lhs" "$rhs"
  assert_failure
  assert_output_matches "WARN.* $lhs differs from $rhs"
}

@test "$SUITE: --edit opens _GO_DIFF_EDITOR if the files differ" {
  skip_if_system_missing 'diff'

  local lhs="$TEST_GO_ROOTDIR/foo"
  local rhs="$TEST_GO_ROOTDIR/bar"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf '%s\n' 'foo' >"$lhs"
  printf '%s\n' 'bar' >"$rhs"

  stub_program_in_path 'vimdiff' \
    'printf "%s\n" "LHS: $1" "RHS: $2"'

  _GO_DIFF_EDITOR='vimdiff' run "$TEST_GO_SCRIPT" --edit "$lhs" "$rhs"
  restore_program_in_path 'vimdiff'

  assert_failure
  assert_lines_match \
    "WARN.* $lhs differs from $rhs" \
    "INFO.* Editing $lhs and $rhs" \
    "LHS: $lhs" \
    "RHS: $rhs"
}
