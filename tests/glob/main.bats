#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

TESTS_DIR="$TEST_GO_ROOTDIR/tests"

setup() {
  mkdir -p "$TESTS_DIR"
}

teardown() {
  remove_test_go_rootdir
}

@test "glob: error on unknown flag" {
  run "$BASH" ./go glob --foobar
  assert_failure 'Unknown flag: --foobar'

  run "$BASH" ./go glob --compact --ignore '*' --foobar
  assert_failure 'Unknown flag: --foobar'
}

@test "glob: error if rootdir not specified" {
  local err_msg='Root directory argument not specified.'
  run "$BASH" ./go glob
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*'
  assert_failure "$err_msg"
}

@test "glob: error if rootdir argument is not a directory" {
  local err_msg='Root directory argument bogus_dir is not a directory.'
  run "$BASH" ./go glob bogus_dir
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*' bogus_dir
  assert_failure "$err_msg"
}

@test "glob: error if file suffix argument not specified" {
  local err_msg='File suffix argument not specified.'
  run "$BASH" ./go glob "$TESTS_DIR"
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*' "$TESTS_DIR"
  assert_failure "$err_msg"
}

@test "glob: error if no files match pattern" {
  run "$BASH" ./go glob "$TESTS_DIR" '.bats'
  assert_failure "\"*\" does not match any .bats files in $TESTS_DIR."

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo'
  assert_failure "\"foo\" does not match any .bats files in $TESTS_DIR."
}

@test "glob: no glob patterns defaults to matching all files" {
  local expected=(
    "$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats" "$TESTS_DIR/foo.bats")
  touch "${expected[@]}"

  run "$BASH" ./go glob "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: start glob matches all files" {
  local expected=(
    "$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats" "$TESTS_DIR/foo.bats")
  touch "${expected[@]}"

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' '*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: --compact strips rootdir and suffix from all files" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  local expected=('bar' 'baz' 'foo')

  run "$BASH" ./go glob --compact "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: match nothing if the suffix doesn't match" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bash'
  local IFS=$'\n'
  assert_failure "\"*\" does not match any .bash files in $TESTS_DIR."
}

@test "glob: set --ignore patterns" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  local expected=('bar' 'baz' 'foo')

  run "$BASH" ./go glob --ignore 'ba*' "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "$TESTS_DIR/foo.bats"

  run "$BASH" ./go glob --ignore 'f*' --compact "$TESTS_DIR" '.bats'
  expected=('bar' 'baz')
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --compact --ignore 'ba*:f*' "$TESTS_DIR" '.bats'
  assert_failure "\"*\" does not match any .bats files in $TESTS_DIR."
}

@test "glob: match single file" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo'
  local IFS=$'\n'
  assert_success "$TESTS_DIR/foo.bats"
}

@test "glob: match multiple files" {
  local expected=("$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats")
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'ba*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
