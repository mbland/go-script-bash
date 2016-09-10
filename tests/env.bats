#! /usr/bin/env bats

load environment
load assertions
load script_helper

setup() {
  create_test_go_script '@go "$@"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: tab completions" {
  run "$TEST_GO_SCRIPT" env --complete 0
  assert_success '-'

  run "$TEST_GO_SCRIPT" env --complete 0 '-'
  assert_success '-'

  run "$TEST_GO_SCRIPT" env --complete 0 '--foo'
  assert_failure ''

  run "$TEST_GO_SCRIPT" env --complete 1 '-' 'invalid'
  assert_failure ''
}

@test "$SUITE: error if no implementation available for SHELL" {
  local shell='nonexistent-sh'
  run env SHELL="$shell" "$TEST_GO_SCRIPT" env

  assert_failure
  assert_line_equals 0 "The $shell shell currently isn't supported."
  assert_line_matches 1 "$_GO_CORE_URL/tree/master/lib/env"
}

@test "$SUITE: error if the ./go script file name contains spaces" {
  local go_script="$TEST_GO_ROOTDIR/go script"
  mv "$TEST_GO_SCRIPT" "$go_script"
  [[ "$?" -eq '0' ]]

  run env SHELL='bash' "$go_script" env
  assert_failure

  local expected="ERROR: the \"${go_script#$TEST_GO_ROOTDIR/}\" script "
  expected+='must not contain spaces'
  assert_output_matches "$expected"
}

@test "$SUITE: show usage if no function name argument" {
  local go_script="$TEST_GO_ROOTDIR/my-go"
  mv "$TEST_GO_SCRIPT" "$go_script"
  [[ "$?" -eq '0' ]]

  run env SHELL='bash' "$go_script" env
  assert_success
  assert_line_matches 0 "Define the \"${go_script#$TEST_GO_ROOTDIR/}\" function"
  assert_line_equals 2 "eval \"\$($go_script env -)\""
}

@test "$SUITE: error if shell impl doesn't contain eval line" {
  echo '' > "$_GO_ROOTDIR/lib/env/badsh"
  [[ "$?" -eq '0' ]]

  run env SHELL='badsh' "$TEST_GO_SCRIPT" env
  rm "$_GO_ROOTDIR/lib/env/badsh"
  [[ "$?" -eq '0' ]]

  assert_failure
  local expected="ERROR: .*badsh must contain a line of the form "
  expected+='"# \.\*%s env -"'
  assert_output_matches "$expected"
}

@test "$SUITE: error if function name contains spaces" {
  run env SHELL='bash' "$TEST_GO_SCRIPT" env 'foo bar'
  assert_failure
  assert_output_matches 'ERROR: "foo bar" must not contain spaces'
}

@test "$SUITE: generate functions using default name" {
  local go_script="$TEST_GO_ROOTDIR/my-go"
  mv "$TEST_GO_SCRIPT" "$go_script"
  [[ "$?" -eq '0' ]]

  run env SHELL='bash' "$go_script" env -
  assert_success
  assert_line_equals 3 '_my-go() {'
  assert_output_matches $'\n''my-go\() \{'
  assert_line_equals -1 'complete -o filenames -F _my-go my-go'
}

@test "$SUITE: generate functions using specified name" {
  run env SHELL='bash' "$TEST_GO_SCRIPT" env go-do
  assert_success
  assert_line_equals 3 '_go-do() {'
  assert_output_matches $'\n''go-do\() \{'
  assert_line_equals -1 'complete -o filenames -F _go-do go-do'
}
