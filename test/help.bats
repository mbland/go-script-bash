#! /usr/bin/env bats

@test "produce help message with successful return for help command" {
  run ./go help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Usage: ./go <command> [arguments...]' ]
}

@test "accept -h, -help, and --help  as help command substitutes" {
  run ./go help
  [ "$status" -eq 0 ]
  local help_output="$output"

  run ./go -h
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]

  run ./go -help
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]

  run ./go --help
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]
}
