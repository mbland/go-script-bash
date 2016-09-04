#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

setup() {
  create_test_go_script
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: scripts dir check successful" {
  run "$TEST_GO_SCRIPT"
  assert_success
}

@test "$SUITE: produce an error if more than one dir specified when sourced" {
  # Overwrite the entire script to force the multiple dir error.
  echo "#! $BASH" >"$TEST_GO_SCRIPT"
  echo ". '$_GO_ROOTDIR/go-core.bash' " \
    "'$TEST_GO_SCRIPTS_RELATIVE_DIR' 'test/scripts'" >>"$TEST_GO_SCRIPT"

  run "$TEST_GO_SCRIPT"
  assert_failure \
    'ERROR: there should be exactly one command script dir specified'
}

@test "$SUITE: produce an error if the script dir does not exist" {
  local expected='ERROR: command script directory '
  expected+="$TEST_GO_SCRIPTS_DIR does not exist"

  rmdir "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"
}

@test "$SUITE: produce an error if the script dir isn't readable or executable" {
  if [[ "$MSYSTEM" = "MINGW64" ]]; then
    # Even using icacls to set permissions, the dir still seems accessible.
    skip "Can't trigger condition on MINGW64"
  fi

  local expected="ERROR: you do not have permission to access the "
  expected+="$TEST_GO_SCRIPTS_DIR directory"

  chmod 200 "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"

  chmod 600 "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"
}
