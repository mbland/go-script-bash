#! /usr/bin/env bats

load environment
load assertions

@test "help: produce message with successful return for help command" {
  run tests/go help
  assert_success
  assert_line_equals 0 'Usage: tests/go <command> [arguments...]'
}

@test "help: accept -h, -help, and --help as synonyms" {
  run tests/go help
  assert_success

  local help_output="$output"

  run tests/go -h
  assert_success "$help_output"

  run tests/go -help
  assert_success "$help_output"

  run tests/go --help
  assert_success "$help_output"
}
