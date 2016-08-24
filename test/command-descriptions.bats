#! /usr/bin/env bats

setup() {
  . 'lib/command_descriptions'
}

@test "check command path passes" {
  run _@go.check_command_path go
  [[ $status -eq 0 ]]
  [[ -z $output ]]
}

@test "check command path produces an error if no path is specified" {
  run _@go.check_command_path
  [[ $status -eq 1 ]]
  [[ $output = 'ERROR: no command script specified' ]]
}

@test "check command path produces an error if the path doesn't exist" {
  run _@go.check_command_path foobar
  [[ $status -eq 1 ]]
  [[ $output = 'ERROR: command script "foobar" does not exist' ]]
}

@test "check command_summary fails if the path doesn't exist" {
  run _@go.command_summary foobar
  [[ $status -eq 1 ]]
  [[ $output = 'ERROR: command script "foobar" does not exist' ]]
}

@test "check command_description fails if the path doesn't exist" {
  run _@go.command_description foobar
  [[ $status -eq 1 ]]
  [[ $output = 'ERROR: command script "foobar" does not exist' ]]
}

@test "filter description line" {
  local _GO_CMD='test-go'
  local cmd_name='test-command'

  local line='The script is {{go}}, '
  line+='the command is {{cmd}}, and '
  line+='the project root is {{root}}.'


  _@go.filter_description_line
  [[ $status -eq 0 ]]

  local expected="The script is test-go, "
  expected+='the command is test-command, and '
  expected+="the project root is $_GO_ROOTDIR."
  [[ $line = $expected ]]
}

@test "format summary without folding if total length <= COLUMNS" {
  local cmd_name='test-command'
  local summary='Summary for a command parsed from the file header comment'
  local expected="  $cmd_name  $summary"

  # Add one to account for the newline, though $() trims it.
  COLUMNS="$((${#expected} + 1))"
  local formatted="$(_@go.format_summary "$cmd_name" "$summary" "${#cmd_name}")"

  [[ $formatted = $expected ]]
}

@test "format summary with folding if total length > COLUMNS" {
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

  [[ $formatted = $expected ]]
}
