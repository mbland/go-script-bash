#! /usr/bin/env bats

setup() {
  COLUMNS=1000
}

@test "aliases: with no arguments, list all aliases" {
  run "$BASH" ./go aliases
  [[ "$status" -eq '0' ]]
  [[ "${lines[0]}" = 'awk' ]]  # first alias
  [[ "${lines[$((${#lines[@]} - 1))]}" = 'sed' ]]  # last alias
}

@test "aliases: tab completions" {
  run "$BASH" ./go aliases --complete
  [[ "$status" -eq '0' ]]
  [[ "$output" = '--exists' ]]
}

@test "aliases: error on unknown flag" {
  run "$BASH" ./go aliases --foobar
  [[ "$status" -eq '1' ]]
  [[ "$output" = 'ERROR: unknown flag: --foobar' ]]
}

@test "aliases: help filter" {
  run "$BASH" ./go aliases --help-filter 'BEGIN {{_GO_ALIAS_CMDS}} END'
  [[ "$status" -eq '0' ]]

  local expected=($("$BASH" ./go aliases))
  [[ "$output" = "BEGIN ${expected[*]} END" ]]
}

@test "aliases: error if no argument after valid flag" {
  run "$BASH" ./go aliases --exists
  [[ "$status" -eq '1' ]]
  [[ "$output" = "ERROR: no argument given after --exists flag" ]]
}

@test "aliases: return true if alias exists, false if not" {
  run "$BASH" ./go aliases --exists ls
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]

  # No flag is the same as --exists.
  run "$BASH" ./go aliases ls
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]

  run "$BASH" ./go aliases --exists foobar
  [[ "$status" -eq '1' ]]
  [[ -z "$output" ]]

  run "$BASH" ./go aliases --help foobar
  [[ "$status" -eq '1' ]]
  [[ -z "$output" ]]

  run "$BASH" ./go aliases foobar
  [[ "$status" -eq '1' ]]
  [[ -z "$output" ]]
}

@test "aliases: show generic help for alias" {
  run "$BASH" ./go aliases --help ls
  [[ "$status" -eq '0' ]]

  local expected=("./go ls - Shell alias that will execute in $_GO_ROOTDIR")
  expected+=('Filename completion is available via the "./go env" command.')

  [[ "${lines[0]}" = "${expected[0]}" ]]
  [[ "${lines[1]}" = "${expected[1]}" ]]
}

@test "aliases: specialize help for cd, pushd when running script directly" {
  run "$BASH" ./go aliases --help cd
  [[ "$status" -eq '0' ]]

  local expected=("./go cd - Shell alias that will execute in $_GO_ROOTDIR")
  expected+=('Filename completion is available via the "./go env" command.')
  expected+=('NOTE: The "cd" alias will only be available after using ')
  expected[2]+='"./go env" to set up your shell environment.'

  [[ "${lines[0]}" = "${expected[0]}" ]]
  [[ "${lines[1]}" = "${expected[1]}" ]]
  [[ "${lines[2]}" = "${expected[2]}" ]]

  run "$BASH" ./go aliases --help pushd
  [[ "$status" -eq '0' ]]

  expected[0]="${expected[0]/go cd/go pushd}"
  expected[2]="${expected[2]/\"cd\"/\"pushd\"}"

  [[ "${lines[0]}" = "${expected[0]}" ]]
  [[ "${lines[1]}" = "${expected[1]}" ]]
  [[ "${lines[2]}" = "${expected[2]}" ]]
}

@test "aliases: leave help generic for cd, pushd when using env function" {
  # Setting _GO_CMD will trick the script into thinking the shell function is
  # running it.
  
  run env _GO_CMD='test-go' "$BASH" ./go aliases --help cd
  [[ "$status" -eq '0' ]]

  local expected=("test-go cd - Shell alias that will execute in $_GO_ROOTDIR")
  expected+=('Filename completion is available via the "test-go env" command.')

  [[ "${lines[0]}" = "${expected[0]}" ]]
  [[ "${lines[1]}" = "${expected[1]}" ]]
  [[ -z "${lines[2]}" ]]

  run env _GO_CMD='test-go' "$BASH" ./go aliases --help pushd
  [[ "$status" -eq '0' ]]

  expected[0]="${expected[0]/test-go cd/test-go pushd}"

  [[ "${lines[0]}" = "${expected[0]}" ]]
  [[ "${lines[1]}" = "${expected[1]}" ]]
  [[ -z "${lines[2]}" ]]
}
