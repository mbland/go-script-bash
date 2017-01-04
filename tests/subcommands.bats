#! /usr/bin/env bats

load environment

EXPECTED_SUBCOMMAND_LISTING=('Available subcommands of "foo" are:'
  ''
  '  bar   Do bar stuff'
  '  baz   Do baz stuff'
  '  quux  Do quux stuff')

setup() {
  create_test_go_script '@go "$@"'
  create_test_command_script 'foo' '. "$_GO_USE_MODULES" subcommands' \
    '@go.show_subcommands'
  create_test_command_script 'foo.d/bar' '# Do bar stuff'
  create_test_command_script 'foo.d/baz' '# Do baz stuff'
  create_test_command_script 'foo.d/quux' '# Do quux stuff'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: show subcommands" {
  run "$TEST_GO_SCRIPT" 'foo'
  local IFS=$'\n'
  assert_success "${EXPECTED_SUBCOMMAND_LISTING[*]}"
}

@test "$SUITE: show nothing for correct subcommand" {
  run "$TEST_GO_SCRIPT" 'foo' 'bar'
  assert_success ''
}

@test "$SUITE: show error for incorrect subcommands" {
  run "$TEST_GO_SCRIPT" 'foo' 'xyzzy' 'plugh'
  local err_msg=$'"xyzzy" is not an available subcommand of "foo".\n\n'
  local IFS=$'\n'
  assert_failure "${err_msg}${EXPECTED_SUBCOMMAND_LISTING[*]}"
}
