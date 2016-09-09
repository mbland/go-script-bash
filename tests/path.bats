#! /usr/bin/env bats

load environment
load assertions
load script_helper

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: shell alias" {
  run ./go path cd
  assert_success '[alias]'
}

@test "$SUITE: builtin path" {
  run ./go path path
  assert_success "[builtin] libexec/path"
}

@test "$SUITE: user script path" {
  run ./go path test
  assert_success "scripts/test"
}

@test "$SUITE: user subcommand script with arguments" {
  mkdir -p "$TEST_GO_SCRIPTS_DIR/foo.d/bar.d"
  create_test_command_script foo
  create_test_command_script foo.d/bar
  create_test_command_script foo.d/bar.d/baz
  create_test_go_script '@go "$@"'

  run "$TEST_GO_SCRIPT" path foo bar baz --quux --xyzzy plugh frobozz
  assert_success "${TEST_GO_SCRIPTS_DIR#$TEST_GO_ROOTDIR/}/foo.d/bar.d/baz"
}

@test "$SUITE: error if command doesn't exist" {
  run ./go path foo
  assert_failure
  assert_line_equals 0 'Unknown command: foo'
}
