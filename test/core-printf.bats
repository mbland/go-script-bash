#! /usr/bin/env bats

load environment
load assertions

setup() {
  declare -g TEST_GO_SCRIPT="$BATS_TMPDIR/go"
  echo . "$_GO_ROOTDIR/go-core.bash" '.' >>"$TEST_GO_SCRIPT"
  echo '@go.printf "%s" "$@"' >>"$TEST_GO_SCRIPT"

  declare -g TEST_TEXT='1234567890 1234567890 1234567890'
}

@test "core: wrap text according to COLUMNS if fold command is available" {
  run env COLUMNS=11 "$BASH" "$TEST_GO_SCRIPT" "$TEST_TEXT"
  assert_success
  assert_equal '3' "${#lines[@]}" 'number of output lines'
  assert_line_equals 0 '1234567890 '
  assert_line_equals 1 '1234567890 '
  assert_line_equals 2 '1234567890'
}

@test "core: don't wrap text if fold command isn't available" {
  run env PATH= COLUMNS=11 "$BASH" "$TEST_GO_SCRIPT" "$TEST_TEXT"
  assert_success "$TEST_TEXT"
  assert_equal '1' "${#lines[@]}" 'number of output lines'
}

teardown() {
  rm "$TEST_GO_SCRIPT"
}
