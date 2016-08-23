#! /usr/bin/env bats

@test "produce help message with error return when no args" {
  run test/go
  [[ $status -eq 1 ]]
  [[ ${lines[0]} = 'Usage: test/go <command> [arguments...]' ]]
}

@test "check exported global constants" {
  [[ $_GO_ROOTDIR = $PWD ]]
  [[ $_GO_SCRIPT == "$_GO_ROOTDIR/go" ]]
  [[ -n $COLUMNS ]]
}
