#! /usr/bin/env bats

load ../environment

TESTS_DIR="$TEST_GO_ROOTDIR/tests"

setup() {
  mkdir -p "$TESTS_DIR"
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: zero arguments" {
  local expected=('--trim' '--ignore')
  expected+=($(compgen -d))

  run ./go glob --complete 0
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: first argument" {
  local expected=('--trim' '--ignore')
  expected+=($(compgen -d))

  run ./go glob --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"

  expected=('--trim' '--ignore')
  run ./go glob --complete 0 '-'
  assert_success "${expected[*]}"

  run ./go glob --complete 0 '--t'
  assert_success '--trim'

  run ./go glob --complete 0 '--i'
  assert_success '--ignore'

  expected=($(compgen -f -- 'li'))
  [[ "${#expected[@]}" -ne '0' ]]
  run ./go glob --complete 0 'li'
  assert_success "${expected[*]}"
}

@test "$SUITE: completion omits flags already present" {
  local expected=('--ignore' $(compgen -d))
  run ./go glob --complete 1 '--trim'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run ./go glob --complete 1 '--trim' '-'
  assert_success '--ignore'

  expected[0]='--trim'
  run ./go glob --complete 2 '--ignore' 'foo*:bar*'
  assert_success "${expected[*]}"

  run ./go glob --complete 2 '--ignore' 'foo*:bar*' '-'
  assert_success '--trim'

  unset expected[0]
  run ./go glob --complete 3 '--ignore' 'foo*:bar*' '--trim'
  assert_success "${expected[*]}"

  expected=($(compgen -f -- 'li'))
  [[ "${#expected[@]}" -ne '0' ]]
  run ./go glob --complete 3 '--ignore' 'foo*:bar*' '--trim' 'li'
  assert_success "${expected[*]}"
}

@test "$SUITE: argument does not complete if previous is --ignore" {
  # The next argument should be the GLOBIGNORE value.
  run ./go glob --complete 1 '--ignore'
  assert_failure ''

  run ./go glob --complete 2 '--trim' '--ignore'
  assert_failure ''

  run ./go glob --complete 1 '--ignore' '' 'tests'
  assert_failure
}

@test "$SUITE: argument does not complete if previous is root dir" {
  # The next argument should be the suffix pattern.
  run ./go glob --complete 1 'tests'
  assert_failure ''

  run ./go glob --complete 2 '--trim' 'tests'
  assert_failure ''

  run ./go glob --complete 4 '--trim' '--ignore' 'foo*:bar*' 'tests'
  assert_failure ''
}

@test "$SUITE: arguments before flags only complete other flags" {
  run ./go glob --complete 0 '' '--trim'
  assert_success '--ignore'

  run ./go glob --complete 0 '' '--ignore'
  assert_success '--trim'
}

@test "$SUITE: complete flags before rootdir" {
  local expected=('--trim' '--ignore')
  run ./go glob --complete 0 '' 'tests'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run ./go glob --complete 1 '--trim' '' 'tests'
  assert_success '--ignore'

  run ./go glob --complete 2 '--ignore' 'foo*:bar*' '' 'tests'
  assert_success '--trim'
}

@test "$SUITE: complete rootdir" {
  run ./go glob --complete 0 'tests'
  assert_success 'tests'

  local expected=($(compgen -d 'tests/'))
  run ./go glob --complete 0 'tests/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete top-level glob patterns" {
  touch "$TESTS_DIR"/{foo,bar,baz}.bats
  local expected=('bar' 'baz' 'foo')

  run ./go glob --complete 2 "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run ./go glob --complete 3 '--trim' "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run ./go glob --complete 3 "$TESTS_DIR" '.bats' 'foo'
  assert_success "${expected[*]}"

  run ./go glob --complete 2 "$TESTS_DIR" '.bats' '' 'foo'
  assert_success "${expected[*]}"
}

@test "$SUITE: trim top-level glob patterns with no shared prefix" {
  mkdir "$TESTS_DIR"/{foo,bar,baz}
  touch "$TESTS_DIR"/foo/quux.bats \
    "$TESTS_DIR"/bar/xyzzy.bats \
    "$TESTS_DIR"/baz/plugh.bats
  local expected=('bar/' 'baz/' 'foo/')

  run ./go glob --complete 2 "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: match a file and directory of the same name" {
  mkdir "$TESTS_DIR/foo"
  touch "$TESTS_DIR"/foo{,/bar,/baz}.bats
  local expected=('foo' 'foo/')

  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete second-level glob pattern" {
  mkdir "$TESTS_DIR/foo"
  touch "$TESTS_DIR"/foo{,/bar,/baz}.bats
  local expected=('foo/bar' 'foo/baz')

  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete directories that don't match file names" {
  mkdir "$TESTS_DIR"/foo
  touch "$TESTS_DIR"/foo/{bar,baz}.bats

  local expected=('foo/bar' 'foo/baz')
  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: honor --ignore patterns during completion" {
  mkdir "$TESTS_DIR"/{foo,bar,baz}
  touch "$TESTS_DIR"/{foo/quux,bar/xyzzy,baz/plugh,baz/xyzzy}.bats

  # Remember that --ignore will add the rootdir to all the patterns.
  run ./go glob --complete 4 '--ignore' "foo/*:bar/*:baz/pl*" \
    "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success 'baz/xyzzy'

  # Make sure the --ignore argument has any quotes removed, as the shell will
  # not expand any command line arguments or unquote them during completion.
  run ./go glob --complete 4 '--ignore' "'foo/*:bar/*:baz/pl*'" \
    "$TESTS_DIR" '.bats'
  assert_success 'baz/xyzzy'
}

@test "$SUITE: return error if no matches" {
  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo'
  assert_failure
}

@test "$SUITE: return full path if only one match" {
  mkdir "$TESTS_DIR/foo"
  touch "$TESTS_DIR/foo/bar.bats"
  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  assert_success "foo/bar"
}

@test "$SUITE: return completions with longest possible prefix" {
  mkdir -p "$TESTS_DIR"/foo/bar/{baz,quux}
  touch "$TESTS_DIR"/foo/bar/{baz/xyzzy,quux/plugh}.bats

  local expected=('foo/bar/baz/' 'foo/bar/quux/')
  run ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
