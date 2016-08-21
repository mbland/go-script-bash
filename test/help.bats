#! /usr/bin/env bats

@test "produce help message with successful return for help command" {
  run test/go help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Usage: test/go <command> [arguments...]' ]
}

@test "accept -h, -help, and --help  as help command substitutes" {
  run test/go help
  [ "$status" -eq 0 ]
  local help_output="$output"

  run test/go -h
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]

  run test/go -help
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]

  run test/go --help
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]
}
