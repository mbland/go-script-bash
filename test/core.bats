#! /usr/bin/env bats

@test "produce help message with error return when no args" {
  run ./go
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = 'Usage: ./go <command> [arguments...]' ]
}
