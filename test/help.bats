#! /usr/bin/env bats

load environment
load assertions

@test "help: produce message with successful return for help command" {
  run test/go help
  assert_success
  assert_line_equals 0 'Usage: test/go <command> [arguments...]'
}

@test "help: accept -h, -help, and --help as synonyms" {
  run test/go help
  assert_success

  local help_output="$output"

  run test/go -h
  assert_success "$help_output"

  run test/go -help
  assert_success "$help_output"

  run test/go --help
  assert_success "$help_output"
}
