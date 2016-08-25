#! /usr/bin/env bats

setup() {
  declare -g CORE_TEST_DIR='test/core-test-dir'
  mkdir "$CORE_TEST_DIR"
}

@test "core: produce an error if more than one dir specified when sourced" {
  run ./go-core.bash "$CORE_TEST_DIR" 'test/scripts'
  [[ "$status" -eq '1' ]]
  [[ "$output" = \
    'ERROR: there should be exactly one command script dir specified' ]]
}

@test "core: produce an error if the script dir does not exist" {
  rmdir "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  [[ "$status" -eq '1' ]]

  local expected="ERROR: command script directory $PWD/$CORE_TEST_DIR "
  expected+='does not exist'
  [[ "$output" = "$expected" ]]
}

@test "core: produce an error if the script dir isn't readable or executable" {
  chmod 200 "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  [[ "$status" -eq '1' ]]

  local expected="ERROR: you do not have permission to access the "
  expected+="$PWD/$CORE_TEST_DIR directory"
  [[ "$output" = "$expected" ]]

  chmod 600 "$CORE_TEST_DIR"
  run ./go-core.bash "$CORE_TEST_DIR"
  [[ "$status" -eq '1' ]]

  local expected="ERROR: you do not have permission to access the "
  expected+="$PWD/$CORE_TEST_DIR directory"
  [[ "$output" = "$expected" ]]
}

teardown() {
  if [[ -d "$CORE_TEST_DIR" ]]; then
    chmod 700 "$CORE_TEST_DIR"
    rm -rf "$CORE_TEST_DIR"
  fi
}
