#! /usr/bin/env bats

load environment
load assertions

setup() {
  declare -g TEST_GO_SCRIPT="$BATS_TMPDIR/go"
  declare -g TEST_COMMAND_SCRIPT="$BATS_TMPDIR/test-command"

  echo . "$_GO_ROOTDIR/go-core.bash" '.' >>"$TEST_GO_SCRIPT"
  echo '@go "$@"' >>"$TEST_GO_SCRIPT"
  touch "$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"
}

@test "core: run bash script by sourcing" {
  echo '#!/bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "core: run sh script by sourcing" {
  echo '#!/bin/sh' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "core: run perl script" {
  if ! command -v perl; then
    skip 'perl not installed'
  fi

  echo '#!/bin/perl' >"$TEST_COMMAND_SCRIPT"
  echo 'printf("%s", join(" ", @ARGV))' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can run perl
  assert_success 'Can run perl'
}

@test "core: produce error if script doesn't contain an interpreter line" {
  local expected="The first line of $TEST_COMMAND_SCRIPT does not contain "
  expected+='#!/path/to/interpreter.'

  echo '@go.printf "%s" "$*"' >"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Missing shebang line
  assert_failure "$expected"
}

@test "core: produce error if shebang line not parseable" {
  local expected='Could not parse interpreter from first line of '
  expected+="$TEST_COMMAND_SCRIPT."

  echo '#!' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Shebang line not complete
  assert_failure "$expected"
}

@test "core: parse space after shebang" {
  echo '#! /bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Space after shebang OK
  assert_success 'Space after shebang OK'
}

@test "core: parse /path/to/env bash" {
  echo '#! /path/to/env bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command '/path/to/env' OK
  assert_success '/path/to/env OK'
}

@test "core: ignore flags and arguments after shell name" {
  echo '#!/bin/bash -x' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Flags after interpreter ignored
  assert_success 'Flags after interpreter ignored'
}

teardown() {
  if [[ -f "$TEST_COMMAND_SCRIPT" ]]; then
    rm "$TEST_COMMAND_SCRIPT"
  fi
  rm "$TEST_GO_SCRIPT"
}
