#! /usr/bin/env bats

setup() {
  declare -g GO_SCRIPT="$BATS_TMPDIR/go"
  echo . "$_GO_ROOTDIR/go-core.bash" '.' >>"$GO_SCRIPT"
  echo 'echo "$COLUMNS"' >>"$GO_SCRIPT"
}

@test "set COLUMNS if unset" {
  run env COLUMNS= "$BASH" "$GO_SCRIPT"
  [[ $status -eq 0 ]]
  [[ -n $output ]]
}

@test "honor COLUMNS if already set" {
  run env COLUMNS="example value" "$BASH" "$GO_SCRIPT"
  [[ $status -eq 0 ]]
  [[ $output = 'example value' ]]
}

@test "default COLUMNS to 80 if actual columns can't be determined" {
  run env COLUMNS= PATH= "$BASH" "$GO_SCRIPT"
  [[ $status -eq 0 ]]
  [[ $output = 80 ]]
}

teardown() {
  rm -rf "$GO_SCRIPT"
}
