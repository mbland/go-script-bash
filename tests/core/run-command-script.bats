#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

setup() {
  create_test_go_script '@go "$@"'
  create_test_command_script
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: run bash script by sourcing" {
  echo '#!/bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "$SUITE: run sh script by sourcing" {
  echo '#!/bin/sh' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "$SUITE: run perl script" {
  if ! command -v perl; then
    skip 'perl not installed'
  fi

  echo '#!/bin/perl' >"$TEST_COMMAND_SCRIPT"
  echo 'printf("%s", join(" ", @ARGV))' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can run perl
  assert_success 'Can run perl'
}

@test "$SUITE: produce error if script doesn't contain an interpreter line" {
  if [[ "$MSYSTEM" = "MINGW64" ]]; then
    # The executable check will fail first because there's no `#!` line.
    skip "Can't trigger condition on MINGW64"
  fi

  local expected="The first line of $TEST_COMMAND_SCRIPT does not contain "
  expected+='#!/path/to/interpreter.'

  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Missing shebang line
  assert_failure "$expected"
}

@test "$SUITE: produce error if shebang line not parseable" {
  local expected='Could not parse interpreter from first line of '
  expected+="$TEST_COMMAND_SCRIPT."

  echo '#!' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Shebang line not complete
  assert_failure "$expected"
}

@test "$SUITE: parse space after shebang" {
  echo '#! /bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Space after shebang OK
  assert_success 'Space after shebang OK'
}

@test "$SUITE: parse /path/to/env bash" {
  echo '#! /path/to/env bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command '/path/to/env' OK
  assert_success '/path/to/env OK'
}

@test "$SUITE: ignore flags and arguments after shell name" {
  echo '#!/bin/bash -x' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Flags after interpreter ignored
  assert_success 'Flags after interpreter ignored'
}
