#! /usr/bin/env bats

load environment
load assertions

@test "aliases: with no arguments, list all aliases" {
  run "$BASH" ./go aliases
  assert_success
  assert_line_equals 0 'awk'  # first alias
  assert_line_equals -1 'sed'  # last alias
}

@test "aliases: tab completions" {
  run "$BASH" ./go aliases --complete
  assert_success '--exists'

  run "$BASH" ./go aliases --complete -
  assert_success ''
}

@test "aliases: error on unknown flag" {
  run "$BASH" ./go aliases --foobar
  assert_failure 'ERROR: unknown flag: --foobar'
}

@test "aliases: help filter" {
  local expected=($("$BASH" ./go aliases))
  run "$BASH" ./go aliases --help-filter 'BEGIN {{_GO_ALIAS_CMDS}} END'
  assert_success "BEGIN ${expected[*]} END"
}

@test "aliases: error if no argument after valid flag" {
  run "$BASH" ./go aliases --exists
  assert_failure 'ERROR: no argument given after --exists'
}

@test "aliases: return true if alias exists, false if not" {
  run "$BASH" ./go aliases --exists ls
  assert_success ''

  run "$BASH" ./go aliases --exists foobar
  assert_failure ''

  run "$BASH" ./go aliases --help foobar
  assert_failure ''
}

@test "aliases: error if no flag specified and other arguments present" {
  run "$BASH" ./go aliases ls
  assert_failure \
    'ERROR: with no flag specified, the argument list should be empty'
}

@test "aliases: error if too many arguments present for flag" {
  run "$BASH" ./go aliases --exists ls cat
  assert_failure 'ERROR: only one argument should follow --exists'

  run "$BASH" ./go aliases --help ls cat
  assert_failure 'ERROR: only one argument should follow --help'

  run "$BASH" ./go aliases --help-filter foo bar
  assert_failure 'ERROR: only one argument should follow --help-filter'
}

@test "aliases: show generic help for alias" {
  run "$BASH" ./go aliases --help ls
  assert_success
  assert_line_equals 0 "./go ls - Shell alias that will execute in $_GO_ROOTDIR"
  assert_line_equals 1 \
    'Filename completion is available via the "./go env" command.'
}

@test "aliases: specialize help for cd, pushd when running script directly" {
  run "$BASH" ./go aliases --help cd
  assert_success

  local expected=("./go cd - Shell alias that will execute in $_GO_ROOTDIR")
  expected+=('Filename completion is available via the "./go env" command.')
  expected+=('NOTE: The "cd" alias will only be available after using ')
  expected[2]+='"./go env" to set up your shell environment.'

  assert_line_equals 0 "${expected[0]}"
  assert_line_equals 1 "${expected[1]}"
  assert_line_equals 2 "${expected[2]}"

  run "$BASH" ./go aliases --help pushd
  assert_success
  assert_line_equals 0 "${expected[0]/go cd/go pushd}"
  assert_line_equals 1 "${expected[1]}"
  assert_line_equals 2 "${expected[2]/\"cd\"/\"pushd\"}"
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
