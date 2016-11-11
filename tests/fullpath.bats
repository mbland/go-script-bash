#! /usr/bin/env bats

load environment

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: tab completions" {
  local expected=('--existing')
  expected+=($(compgen -f))

  run ./go fullpath --complete 0
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run ./go fullpath --complete 0 '-'
  assert_success '--existing'

  expected=($(compgen -f -- 'li'))
  [[ "${#expected[@]}" -ne '0' ]]
  run ./go fullpath --complete 0 'li'
  assert_success "${expected[*]}"
}

@test "$SUITE: prints rootdir when no arguments" {
  run ./go fullpath
  assert_success "$_GO_ROOTDIR"

  run ./go fullpath '--existing'
  assert_success "$_GO_ROOTDIR"
}

@test "$SUITE: prefixes non-absolute path arguments with rootdir" {
  run ./go fullpath foo /bar foo/baz /quux/xyzzy plugh
  local expected=(
    "$_GO_ROOTDIR/foo"
    '/bar'
    "$_GO_ROOTDIR/foo/baz"
    '/quux/xyzzy'
    "$_GO_ROOTDIR/plugh")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: only print existing paths" {
  create_test_go_script '@go "$@"'
  mkdir "$TEST_GO_ROOTDIR"/foo
  touch "$TEST_GO_ROOTDIR"/plugh

  run "$TEST_GO_SCRIPT" fullpath --existing foo / foo/baz /quux/xyzzy plugh
  local expected=("$TEST_GO_ROOTDIR/foo" '/' "$TEST_GO_ROOTDIR/plugh")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: expand glob paths" {
  create_test_go_script '@go "$@"'
  mkdir -p "$TEST_GO_ROOTDIR/foo/bar"
  touch "$TEST_GO_ROOTDIR/foo/"{baz,quux}

  run "$TEST_GO_SCRIPT" fullpath --existing 'foo/*' 'foo/baz/*'
  local expected=(
    "$TEST_GO_ROOTDIR/foo/bar"
    "$TEST_GO_ROOTDIR/foo/baz"
    "$TEST_GO_ROOTDIR/foo/quux")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: expand glob paths containing spaces" {
  create_test_go_script '@go "$@"'
  mkdir "$TEST_GO_ROOTDIR/foo bar"
  touch "$TEST_GO_ROOTDIR/foo bar/"{baz,quux,xyzzy}

  run "$TEST_GO_SCRIPT" fullpath --existing 'foo bar/*'
  local expected=(
    "$TEST_GO_ROOTDIR/foo bar/baz"
    "$TEST_GO_ROOTDIR/foo bar/quux"
    "$TEST_GO_ROOTDIR/foo bar/xyzzy")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
