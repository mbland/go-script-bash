#! /usr/bin/env bats

load environment
load assertions
load script_helper

setup() {
  create_test_go_script '@go "$@"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: tab completion" {
  local subcommands=('plugh' 'quux' 'xyzzy')
  create_parent_and_subcommands foo "${subcommands[@]}"
  run "$TEST_GO_SCRIPT" help --complete 0 'foo'
  assert_success 'foo'

  local IFS=$'\n'
  run "$TEST_GO_SCRIPT" help --complete 1 'foo' ''
  assert_success "${subcommands[*]}"

  run "$TEST_GO_SCRIPT" help --complete 1 'foo' 'q'
  assert_success 'quux'
}

@test "$SUITE: produce message with successful return for help command" {
  run "$TEST_GO_SCRIPT" help
  assert_success
  assert_line_equals 0 "Usage: $TEST_GO_SCRIPT <command> [arguments...]"
}

@test "$SUITE: accept -h, -help, and --help as synonyms" {
  run "$TEST_GO_SCRIPT" help
  assert_success

  local help_output="$output"

  run "$TEST_GO_SCRIPT" -h
  assert_success "$help_output"

  run "$TEST_GO_SCRIPT" -help
  assert_success "$help_output"

  run "$TEST_GO_SCRIPT" --help
  assert_success "$help_output"
}

@test "$SUITE: produce message for alias" {
  run "$TEST_GO_SCRIPT" help ls
  assert_success
  assert_line_equals 0 \
    "$TEST_GO_SCRIPT ls - Shell alias that will execute in $TEST_GO_ROOTDIR"
}

@test "$SUITE: error if command doesn't exist" {
  run "$TEST_GO_SCRIPT" help foobar
  assert_failure
  assert_line_equals 0  'Unknown command: foobar'
  assert_line_equals 1  'Available commands are:'
  assert_line_equals 2  '  aliases'
  assert_line_equals -1 '  unenv'
}
