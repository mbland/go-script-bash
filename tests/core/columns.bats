#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

setup() {
  create_test_go_script 'echo "$COLUMNS"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: set COLUMNS if unset" {
  run env COLUMNS= "$TEST_GO_SCRIPT"
  assert_success
  [[ -n "$output" ]]
}

@test "$SUITE: honor COLUMNS if already set" {
  run env COLUMNS="19700918" "$TEST_GO_SCRIPT"
  assert_success '19700918'
}

@test "$SUITE: default COLUMNS to 80 if actual columns can't be determined" {
  run env COLUMNS= PATH= "$BASH" "$TEST_GO_SCRIPT"
  assert_success '80'
}
