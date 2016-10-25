#! /usr/bin/env bats

load environment
load assertions

setup() {
  . 'lib/internal/command_descriptions'
}

@test "$SUITE: check command path passes" {
  run _@go.check_command_path go
  assert_success ''
}

@test "$SUITE: check command path errors if no path is specified" {
  run _@go.check_command_path
  assert_failure 'ERROR: no command script specified'
}

@test "$SUITE: check command path errors if the path doesn't exist" {
  run _@go.check_command_path foobar
  assert_failure 'ERROR: command script "foobar" does not exist'
}

@test "$SUITE: check command_summary fails if the path doesn't exist" {
  run _@go.command_summary foobar
  assert_failure 'ERROR: command script "foobar" does not exist'
}

@test "$SUITE: check command_description fails if the path doesn't exist" {
  run _@go.command_description foobar
  assert_failure 'ERROR: command script "foobar" does not exist'
}

@test "$SUITE: filter description line" {
  local _GO_CMD='test-go'
  local cmd_name='test-command'

  local line='The script is {{go}}, '
  line+='the command is {{cmd}}, and '
  line+='the project root is {{root}}.'

  local expected="The script is test-go, "
  expected+='the command is test-command, and '
  expected+="the project root is $_GO_ROOTDIR."

  _@go.filter_description_line
  assert_success
  assert_equal "$expected" "$line" 'filtered description line'
}

@test "$SUITE: format summary without folding if total length <= COLUMNS" {
  local cmd_name='test-command'
  local summary='Summary for a command parsed from the file header comment'
  local expected="  $cmd_name  $summary"

  # Add one to account for the newline, though $() trims it.
  COLUMNS="$((${#expected} + 1))"
  local formatted="$(_@go.format_summary "$cmd_name" "$summary" "${#cmd_name}")"
  assert_equal "$expected" "$formatted" 'formatted summary'
}

@test "$SUITE: format summary with folding if total length > COLUMNS" {
  local cmd_name='test-command'
  local summary='Summary for a command parsed from the file header comment '
  summary+="that's a bit longer than the current column width"

  COLUMNS=50
  local formatted="$(_@go.format_summary "$cmd_name" "$summary" \
    "$((${#cmd_name} + 5))")"

  local expected
  expected="  test-command       Summary for a command parsed"$'\n'
  expected+="                       from the file header"$'\n'
  expected+="                       comment that's a bit"$'\n'
  expected+="                       longer than the current"$'\n'
  expected+="                       column width"

  assert_equal "$expected" "$formatted" 'formatted summary'
}
