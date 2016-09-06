#! /usr/bin/env bats

load environment
load assertions

@test "$SUITE: produce message with successful return for help command" {
  run ./go help
  assert_success
  assert_line_equals 0 'Usage: ./go <command> [arguments...]'
}

@test "$SUITE: accept -h, -help, and --help as synonyms" {
  run ./go help
  assert_success

  local help_output="$output"

  run ./go -h
  assert_success "$help_output"

  run ./go -help
  assert_success "$help_output"

  run ./go --help
  assert_success "$help_output"
}
