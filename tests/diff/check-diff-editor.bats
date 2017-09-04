#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "diff"'\
    '@go.diff_check_editor'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: fails if __GO_DIFF_EDITOR not defined" {
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "diff"'\
    '_GO_DIFF_EDITOR= @go.diff_check_editor'
  run "$TEST_GO_SCRIPT"
  assert_failure
  assert_output_matches 'FATAL.* _GO_DIFF_EDITOR not defined'
}

@test "$SUITE: fails if _GO_DIFF_EDITOR not found" {
  _GO_DIFF_EDITOR='nonexistent-editor' run "$TEST_GO_SCRIPT"
  assert_failure
  assert_output_matches \
    'FATAL.* _GO_DIFF_EDITOR not installed: nonexistent-editor'
}

@test "$SUITE: does nothing if _GO_DIFF_EDITOR found" {
  stub_program_in_path 'vimdiff'
  _GO_DIFF_EDITOR='vimdiff' run "$TEST_GO_SCRIPT"
  restore_program_in_path 'vimdiff'
  assert_success ''
}
