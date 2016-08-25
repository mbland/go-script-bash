#! /usr/bin/env bats

load assertions

setup() {
  declare -g CORE_TEST_DIR='test/core-test-dir'
  mkdir "$CORE_TEST_DIR"
}

@test "core: produce an error if more than one dir specified when sourced" {
  run ./go-core.bash "$CORE_TEST_DIR" 'test/scripts'
  assert_failure \
    'ERROR: there should be exactly one command script dir specified'
}

@test "core: produce an error if the script dir does not exist" {
  local expected="ERROR: command script directory $PWD/$CORE_TEST_DIR "
  expected+='does not exist'

  rmdir "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  assert_failure "$expected"
}

@test "core: produce an error if the script dir isn't readable or executable" {
  local expected="ERROR: you do not have permission to access the "
  expected+="$PWD/$CORE_TEST_DIR directory"

  chmod 200 "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  assert_failure "$expected"

  expected="ERROR: you do not have permission to access the "
  expected+="$PWD/$CORE_TEST_DIR directory"

  chmod 600 "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  assert_failure "$expected"
}

teardown() {
  if [[ -d "$CORE_TEST_DIR" ]]; then
    chmod 700 "$CORE_TEST_DIR"
    rm -rf "$CORE_TEST_DIR"
  fi
}
