#! /usr/bin/env bats

load ../environment

setup() {
  @go.create_test_go_script
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: scripts dirs successfully set" {
  run "$TEST_GO_SCRIPT"
  assert_success
}

@test "$SUITE: produce an error if no dir specified when sourced" {
  echo "#! /usr/bin/env bash" >"$TEST_GO_SCRIPT"
  echo ". '$_GO_ROOTDIR/go-core.bash' " >>"$TEST_GO_SCRIPT"

  run "$TEST_GO_SCRIPT"
  assert_failure \
    'ERROR: no command script dir specified'
}

@test "$SUITE: produce an error if a script dir does not exist" {
  local expected='ERROR: command script directory '
  expected+="$TEST_GO_SCRIPTS_DIR does not exist"

  rm -rf "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"
}

@test "$SUITE: produce an error if a script dir isn't a directory" {
  rm -rf "$TEST_GO_SCRIPTS_DIR"
  printf '' >"$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "ERROR: $TEST_GO_SCRIPTS_DIR is not a directory"
}

@test "$SUITE: produce an error if a script dir can't be read or accessed" {
  skip_if_cannot_trigger_file_permission_failure

  local expected="ERROR: you do not have permission to access the "
  expected+="$TEST_GO_SCRIPTS_DIR directory"

  chmod 200 "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"

  chmod 600 "$TEST_GO_SCRIPTS_DIR"
  run "$TEST_GO_SCRIPT"
  assert_failure "$expected"
}
