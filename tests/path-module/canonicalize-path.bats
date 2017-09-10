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
  local argv=('result' "$1")

  case "$1" in
  --pwd)
    argv=('--pwd' 'result' "$2")
    ;;
  --parent)
    argv=('--parent' "$2" 'result' "$3")
    ;;
  esac

  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "path"' \
    '@go.canonicalize_path "$@"' \
    'printf "%s\n" "$result"'
  run "$TEST_GO_SCRIPT" "${argv[@]}"
}

@test "$SUITE: leaves a path unchanged" {
  run_canonicalize_path '/foo/bar/baz'
  assert_success '/foo/bar/baz'
}

@test "$SUITE: leaves the empty path unchanged" {
  run_canonicalize_path ''
  assert_success ''
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

@test "$SUITE: leaves empty path unchanged even with --pwd" {
  run_canonicalize_path '--pwd' ''
  assert_success ''
}

@test "$SUITE: leaves absolute path unchanged even with --pwd" {
  run_canonicalize_path '--pwd' '/foo/bar'
  assert_success '/foo/bar'
}

@test "$SUITE: sets relative current dir to PWD" {
  run_canonicalize_path '--pwd' '.'
  assert_success "$TEST_GO_ROOTDIR"
}

@test "$SUITE: sets relative parent dir to parent of PWD" {
  run_canonicalize_path '--pwd' '..'
  assert_success "${TEST_GO_ROOTDIR%/*}"
}

@test "$SUITE: leaves absolute path unchanged even with --parent" {
  run_canonicalize_path '--parent' '/foo/bar' '/foo/bar'
  assert_success '/foo/bar'
}

@test "$SUITE: leaves empty path unchanged even with --parent" {
  run_canonicalize_path '--parent' '/foo/bar' ''
  assert_success ''
}

@test "$SUITE: sets relative current dir to --parent" {
  run_canonicalize_path '--parent' '/foo/bar' '.'
  assert_success '/foo/bar'
}

@test "$SUITE: sets relative parent dir to parent of --parent" {
  run_canonicalize_path '--parent' '/foo/bar' '..'
  assert_success '/foo'
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

@test "$SUITE: resolves a leading relative self" {
  run_canonicalize_path './foo/bar/baz'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: resolves a leading relative self before '..'" {
  run_canonicalize_path './..'
  assert_success '..'
}

@test "$SUITE: resolves a trailing relative self" {
  run_canonicalize_path 'foo/bar/baz/.'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: resolves multiple relative selves" {
  run_canonicalize_path 'foo/./bar/././baz/././.'
  assert_success 'foo/bar/baz'
}

@test "$SUITE: resolves multiple relative parents, selves" {
  run_canonicalize_path 'foo/./bar/./.././.././baz/./quux/..'
  assert_success 'baz'
}
