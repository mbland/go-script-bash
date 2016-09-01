#! /usr/bin/env bats

load ../environment
load ../assertions

@test "glob/completions: zero arguments" {
  local expected=('--compact' '--ignore')
  expected+=($(compgen -d))

  run "$BASH" ./go glob --complete 0
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob/completions: zeroth argument" {
  local expected=('--compact' '--ignore')
  expected+=($(compgen -d))

  run "$BASH" ./go glob --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"

  expected=('--compact' '--ignore')
  run "$BASH" ./go glob --complete 0 '-'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 0 '--c'
  assert_success '--compact'

  run "$BASH" ./go glob --complete 0 '--i'
  assert_success '--ignore'

  expected=('lib' 'libexec')
  run "$BASH" ./go glob --complete 0 'li'
  assert_success "${expected[*]}"
}
