#! /usr/bin/env bats

load environment
load "$_GO_CORE_DIR/lib/bats/assertion-test-helpers"

setup() {
  test_filter
}

teardown() {
  remove_bats_test_dirs
}

emit_debug_info() {
  printf 'STATUS: %s\nOUTPUT:\n%s\n' "$status" "$output" >&2
}

@test "$SUITE: printf_with_error" {
  run printf_with_error 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '1' ]
  [ "$output" == 'foo bar baz' ]

  PRINTF_ERROR='127' run printf_with_error 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '127' ]
  [ "$output" == 'foo bar baz' ]
}

@test "$SUITE: printf_to_test_output_file" {
  run printf_to_test_output_file 'foo bar baz'
  emit_debug_info
  [ "$status" -eq '0' ]
  [ -z "$output" ]
  [ "$(< "$TEST_OUTPUT_FILE")" == 'foo bar baz' ]
}
