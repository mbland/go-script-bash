#! /usr/bin/env bats

load environment
load assertions

@test "core: check exported global constants" {
  assert_equal "$PWD" "$_GO_ROOTDIR" 'working dir'
  assert_equal "$_GO_ROOTDIR/go" "$_GO_SCRIPT" 'go script path'
}

@test "core: produce help message with error return when no args" {
  run tests/go
  assert_failure
  assert_line_equals 0 'Usage: tests/go <command> [arguments...]'
}

@test "core: produce error for an unknown flag" {
  run tests/go -foobar
  assert_failure
  assert_line_equals 0 'Unknown flag: -foobar'
  assert_line_equals 1 'Usage: tests/go <command> [arguments...]'
}

@test "core: invoke editor on edit command" {
  run env EDITOR=echo tests/go edit 'editor invoked'
  assert_success 'editor invoked'
}

@test "core: invoke run command" {
  run tests/go run echo run command invoked
  assert_success 'run command invoked'
}

@test "core: produce error on cd" {
  local expected
  expected+='cd is only available after using "tests/go env" to set up '$'\n'
  expected+='your shell environment.'

  COLUMNS=60
  run tests/go 'cd'
  assert_failure "$expected"
}

@test "core: produce error on pushd" {
  local expected
  expected+='pushd is only available after using "tests/go env" to set '$'\n'
  expected+='up your shell environment.'

  COLUMNS=60
  run tests/go 'pushd'
  assert_failure "$expected"
}

@test "core: produce error on unenv" {
  local expected
  expected+='unenv is only available after using "tests/go env" to set '$'\n'
  expected+='up your shell environment.'

  COLUMNS=60
  run tests/go 'unenv'
  assert_failure "$expected"
}

@test "core: run shell alias command" {
  run tests/go grep "$BATS_TEST_DESCRIPTION" "$BATS_TEST_FILENAME" >&2

  if command -v 'grep'; then
    assert_success "@test \"$BATS_TEST_DESCRIPTION\" {"
  else
    assert_failure
  fi
}

@test "core: produce error and list available commands if command not found" {
  run tests/go foobar
  assert_failure
  assert_line_equals 0 'Unknown command: foobar'
  assert_line_equals 1 'Available commands are:'
  assert_line_equals 2 '  aliases'
  assert_line_equals -1 '  unenv'
}
