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

@test "glob/complete: first argument" {
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

@test "glob/complete: completion omits flags already present" {
  local expected=('--ignore' $(compgen -d))
  run "$BASH" ./go glob --complete 1 '--compact'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 1 '--compact' '-'
  assert_success '--ignore'

  expected[0]='--compact'
  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*' '-'
  assert_success '--compact'

  unset expected[0]
  run "$BASH" ./go glob --complete 3 '--ignore' 'foo*:bar*' '--compact'
  assert_success "${expected[*]}"

  expected=('lib' 'libexec')
  run "$BASH" ./go glob --complete 3 '--ignore' 'foo*:bar*' '--compact' 'li'
  assert_success "${expected[*]}"
}

@test "glob/complete: argument does not complete if previous is --ignore" {
  # The next argument should be the GLOBIGNORE value.
  run "$BASH" ./go glob --complete 1 '--ignore'
  assert_failure ''

  run "$BASH" ./go glob --complete 2 '--compact' '--ignore'
  assert_failure ''

  run "$BASH" ./go glob --complete 1 '--ignore' '' 'tests'
  assert_failure
}

@test "glob/complete: argument does not complete if previous is root dir" {
  # The next argument should be the suffix pattern.
  run "$BASH" ./go glob --complete 1 'tests'
  assert_failure ''

  run "$BASH" ./go glob --complete 2 '--compact' 'tests'
  assert_failure ''

  run "$BASH" ./go glob --complete 4 '--compact' '--ignore' 'foo*:bar*' 'tests'
  assert_failure ''
}

@test "glob/complete: arguments before flags only complete other flags" {
  run "$BASH" ./go glob --complete 0 '' '--compact'
  assert_success '--ignore'

  run "$BASH" ./go glob --complete 0 '' '--ignore'
  assert_success '--compact'
}

@test "glob/complete: complete flags before rootdir" {
  local expected=('--compact' '--ignore')
  run "$BASH" ./go glob --complete 0 '' 'tests'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 1 '--compact' '' 'tests'
  assert_success '--ignore'

  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*' '' 'tests'
  assert_success '--compact'
}

fill_expected_globs() {
  local rootdir="${1%/*}"
  local f 
  expected=()
  for f in $1/*$2; do
    f="${f%$2}"
    expected+=("$f")
    if [[ -d "$f" ]]; then
      expected+=("$f/")
    fi
  done
  expected=("${expected[@]#$rootdir/}")
}

@test "glob/complete: complete top-level glob patterns" {
  local expected=()
  fill_expected_globs 'tests' '.bats'
  run "$BASH" ./go glob --complete 2 'tests' '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 5 '--compact' '--ignore' 'f*' 'tests' '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 3 'tests' '.bats' 'foo'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 2 'tests' '.bats' '' 'foo'
  assert_success "${expected[*]}"
}

@test "glob/complete: match a file and directory of the same name" {
  local expected=('core' 'core/')
  run "$BASH" ./go glob --complete 2 'tests' '.bats' 'core'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob/complete: complete second-level glob pattern" {
  local expected=()
  fill_expected_globs 'tests/core' '.bats'
  run "$BASH" ./go glob --complete 2 'tests' '.bats' 'core/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob/complete: honor --ignore patterns during completion" {
  local ignored="tests/core*:tests/path*"
  local expected=()

  local GLOBIGNORE="$ignored"
  fill_expected_globs 'tests' '.bats'
  unset "GLOBIGNORE"

  # Remember that --ignore will add the rootdir to all the patterns.
  ignored="${ignored//tests\//}"
  run "$BASH" ./go glob --complete 4 '--ignore' "$ignored" 'tests' '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
