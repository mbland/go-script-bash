#! /usr/bin/env bats

load assertions

@test "core: check exported global constants" {
  assert_equal "$PWD" "$_GO_ROOTDIR" 'working dir'
  assert_equal "$_GO_ROOTDIR/go" "$_GO_SCRIPT" 'go script path'
  [[ -n "$COLUMNS" ]]
}

@test "core: produce help message with error return when no args" {
  run test/go
  assert_failure
  assert_line_equals 0 'Usage: test/go <command> [arguments...]'
}

@test "core: produce error for an unknown flag" {
  run test/go -foobar
  assert_failure
  assert_line_equals 0 'Unknown flag: -foobar'
  assert_line_equals 1 'Usage: test/go <command> [arguments...]'
}

@test "core: invoke editor on edit command" {
  run env EDITOR=echo test/go edit 'editor invoked'
  assert_success 'editor invoked' ]]
}

@test "core: invoke run command" {
  run test/go run echo run command invoked
  assert_success 'run command invoked' ]]
}

@test "core: produce error on cd" {
  local expected
  expected+='cd is only available after using "test/go env" to set up '$'\n'
  expected+='your shell environment.'

  COLUMNS=60
  run test/go 'cd'
  assert_failure "$expected"
}

@test "core: produce error on pushd" {
  local expected
  expected+='pushd is only available after using "test/go env" to set up '$'\n'
  expected+='your shell environment.'

  COLUMNS=60
  run test/go 'pushd'
  assert_failure "$expected"
}

@test "core: produce error on unenv" {
  local expected
  expected+='unenv is only available after using "test/go env" to set up '$'\n'
  expected+='your shell environment.'

  COLUMNS=60
  run test/go 'unenv'
  assert_failure "$expected"
}

@test "core: run shell alias command" {
  run test/go grep "$BATS_TEST_DESCRIPTION" "$BATS_TEST_FILENAME" >&2

  if command -v 'grep'; then
    assert_success "@test \"$BATS_TEST_DESCRIPTION\" {"
  else
    assert_failure
  fi
}

@test "core: produce error and list available commands if command not found" {
  run test/go foobar
  assert_failure
  assert_line_equals 0 'Unknown command: foobar'
  assert_line_equals 1 'Available commands are:'
  assert_line_equals 2 '  aliases'
  assert_line_equals -1 '  unenv'
}
