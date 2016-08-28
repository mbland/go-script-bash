#! /usr/bin/env bats

load environment
load assertions

@test "builtins: no args lists all builtin commands" {
  run "$BASH" ./go 'builtins'
  assert_success
  assert_line_equals 0 "aliases" "first builtin"
  assert_line_equals -1 "unenv" "last builtin"
}

@test "builtins: tab completions" {
  run "$BASH" ./go builtins --complete 0 ''
  assert_success '--exists --summaries'

  run "$BASH" ./go builtins --complete 0 -
  assert_success '--exists --summaries'

  run "$BASH" ./go builtins --complete 1 --exists
  assert_success ''
}

@test "builtins: return true if a builtin command exists, false if not" {
  run "$BASH" ./go builtins --exists builtins
  assert_success ''

  run "$BASH" ./go builtins --exists foobar
  assert_failure ''
}

@test "builtins: error if no flag specified and other arguments present" {
  run "$BASH" ./go builtins builtins
  assert_failure \
    'ERROR: with no flag specified, the argument list should be empty'
}

@test "builtins: error if too many arguments present for flag" {
  run "$BASH" ./go builtins --summaries builtins aliases
  assert_failure 'ERROR: --summaries takes no arguments'

  run "$BASH" ./go builtins --exists builtins aliases
  assert_failure 'ERROR: only one argument should follow --exists'

  run "$BASH" ./go builtins --help-filter builtins aliases
  assert_failure 'ERROR: only one argument should follow --help-filter'
}

@test "builtins: error if --exists not followed by a command name" {
  run "$BASH" ./go builtins --exists
  assert_failure 'ERROR: no argument given after --exists'
}

@test "builtins: error on unknown flag" {
  run "$BASH" ./go builtins --foobar
  assert_failure 'ERROR: unknown flag: --foobar'
}

@test "builtins: list builtin command summaries" {
  local builtins=($("$BASH" ./go builtins))
  local longest_name_len=0
  local cmd_name

  for cmd_name in "${builtins[@]}"; do
    if [[ "${#cmd_name}" -gt "$longest_name_len" ]]; then
      longest_name_len="${#cmd_name}"
    fi
  done

  run "$BASH" ./go builtins --summaries
  assert_success

  . lib/command_descriptions
  local __go_cmd_desc=''
  local first_cmd="${builtins[0]}"
  local last_cmd="${builtins[$((${#builtins[@]} - 1))]}"

  _@go.command_summary "libexec/$first_cmd"
  assert_line_equals 0 \
    "$(_@go.format_summary "$first_cmd" "$__go_cmd_desc" "$longest_name_len")" \
    "first builtin summary"

  _@go.command_summary "libexec/$last_cmd"
  assert_line_equals -1 \
    "$(_@go.format_summary "$last_cmd" "$__go_cmd_desc" "$longest_name_len")" \
    "last builtin summary"
}

@test "builtins: help filter" {
  run "$BASH" ./go builtins --help-filter 'BEGIN {{_GO_BUILTIN_SUMMARIES}} END'

  local IFS=$'\n'
  local expected=($("$BASH" ./go builtins --summaries))
  assert_success "BEGIN ${expected[*]} END"
}
