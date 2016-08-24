#! /usr/bin/env bats

setup() {
  declare -g TEST_GO_SCRIPT="$BATS_TMPDIR/go"
  echo . "$_GO_ROOTDIR/go-core.bash" '.' >>"$TEST_GO_SCRIPT"
  echo '@go.printf "%s" "$@"' >>"$TEST_GO_SCRIPT"

  declare -g TEST_TEXT='1234567890 1234567890 1234567890'
}

@test "wrap text according to COLUMNS if fold command is available" {
  run env COLUMNS=11 "$BASH" "$TEST_GO_SCRIPT" "$TEST_TEXT"
  [[ $status -eq 0 ]]
  [[ ${#lines[@]} -eq 3 ]]
  [[ ${lines[0]} = '1234567890 ' ]]
  [[ ${lines[1]} = '1234567890 ' ]]
  [[ ${lines[2]} = 1234567890 ]]
}

@test "don't wrap text if fold command isn't available" {
  run env PATH= COLUMNS=11 "$BASH" "$TEST_GO_SCRIPT" "$TEST_TEXT"
  [[ $status -eq 0 ]]
  [[ ${#lines[@]} -eq 1 ]]
  [[ $output = $TEST_TEXT ]]
}

teardown() {
  rm "$TEST_GO_SCRIPT"
}
