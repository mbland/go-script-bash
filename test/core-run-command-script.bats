#! /usr/bin/env bats

setup() {
  declare -g TEST_GO_SCRIPT="$BATS_TMPDIR/go"
  declare -g TEST_COMMAND_SCRIPT="$BATS_TMPDIR/test-command"

  echo . "$_GO_ROOTDIR/go-core.bash" '.' >>"$TEST_GO_SCRIPT"
  echo '@go "$@"' >>"$TEST_GO_SCRIPT"
}

@test "run bash script by sourcing" {
  echo '#!/bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  [[ $status -eq 0 ]]
  [[ $output = 'Can use @go.printf' ]]
}

@test "run sh script by sourcing" {
  echo '#!/bin/sh' >"$TEST_COMMAND_SCRIPT"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  [[ $status -eq 0 ]]
  [[ $output = 'Can use @go.printf' ]]
}

@test "run perl script" {
  if ! command -v perl; then
    skip 'perl not installed'
  fi

  echo '#!/bin/perl' >"$TEST_COMMAND_SCRIPT"
  echo 'printf("%s", join(" ", @ARGV))' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Can run perl
  [[ $status -eq 0 ]]
  [[ $output = 'Can run perl' ]]
}

@test "produce error if script doesn't contain an interpreter line" {
  echo '@go.printf "%s" "$*"' >"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Missing shebang line
  [[ $status -eq 1 ]]

  local expected="The first line of $TEST_COMMAND_SCRIPT does not contain "
  expected+='#!/path/to/interpreter.'
  [[ $output = $expected ]]
}

@test "produce error if shebang line not parseable" {
  echo '#!' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Shebang line not complete
  [[ $status -eq 1 ]]

  local expected='Could not parse interpreter from first line of '
  expected+="$TEST_COMMAND_SCRIPT."
  [[ $output = $expected ]]
}

@test "parse space after shebang" {
  echo '#! /bin/bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Space after shebang OK
  [[ $status -eq 0 ]]
  [[ $output = 'Space after shebang OK' ]]
}

@test "parse /path/to/env bash" {
  echo '#! /path/to/env bash' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command '/path/to/env' OK
  [[ $status -eq 0 ]]
  [[ $output = '/path/to/env OK' ]]
}

@test "ignore flags and arguments after shell name" {
  echo '#!/bin/bash -x' >"$TEST_COMMAND_SCRIPT"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT"
  chmod 700 "$TEST_COMMAND_SCRIPT"

  run "$BASH" "$TEST_GO_SCRIPT" test-command Flags after interpreter ignored
  [[ $status -eq 0 ]]
  [[ $output = 'Flags after interpreter ignored' ]]
}

teardown() {
  if [[ -f $TEST_COMMAND_SCRIPT ]]; then
    rm "$TEST_COMMAND_SCRIPT"
  fi
  rm "$TEST_GO_SCRIPT"
}
