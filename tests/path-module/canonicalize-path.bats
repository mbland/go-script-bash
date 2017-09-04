#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/path"

setup() {
  test_filter
}

teardown() {
  @go.remove_test_go_rootdir
}

run_canonicalize_path() {
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "path"' \
    '@go.canonicalize_path "result" "$1"' \
    'printf "%s\n" "$result"'
  run "$TEST_GO_SCRIPT" "$1"      
}

@test "$SUITE: leaves a path unchanged" {
  run_canonicalize_path '/foo/bar/baz'
  assert_success '/foo/bar/baz'
}

@test "$SUITE: leaves root path unchanged" {
  run_canonicalize_path '/'
  assert_success '/'
}

@test "$SUITE: root path relative self" {
  run_canonicalize_path '/.'
  assert_success '/'
}

@test "$SUITE: root path dotfile" {
  run_canonicalize_path '/.bashrc'
  assert_success '/.bashrc'
}

@test "$SUITE: leaves relative current dir path unchanged" {
  run_canonicalize_path '.'
  assert_success '.'
}

@test "$SUITE: leaves relative parent dir path unchanged" {
  run_canonicalize_path '..'
  assert_success '..'
}

@test "$SUITE: removes extra root slashes, parents" {
  run_canonicalize_path '//..///..////../////'
  assert_success '/'
}

@test "$SUITE: removes all extra slashes" {
  run_canonicalize_path '//foo///bar////baz/////'
  assert_success '/foo/bar/baz'
}

@test "$SUITE: resolves a relative parent" {
  run_canonicalize_path 'foo/bar/../baz'
  assert_success 'foo/baz'
}

@test "$SUITE: resolves multiple relative parents" {
  run_canonicalize_path 'foo/bar/../../baz/quux/..'
  assert_success 'baz'
}

@test "$SUITE: resolves relative parents beyond beginning" {
  run_canonicalize_path 'foo/bar/../../baz/quux/../../../..'
  assert_success '../..'
}

@test "$SUITE: resolves relative parents beyond the root" {
  run_canonicalize_path '/foo/bar/../../../baz/../../quux/xyzzy/../../../plugh'
  assert_success '/plugh'
}

@test "$SUITE: resolves a relative self" {
  run_canonicalize_path 'foo/bar/./baz'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: resolves multiple relative selves" {
  run_canonicalize_path 'foo/./bar/././baz/./././'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: resolves multiple relative parents, selves" {
  run_canonicalize_path 'foo/./bar/./.././.././baz/./quux/..'
  assert_success 'baz'
}
