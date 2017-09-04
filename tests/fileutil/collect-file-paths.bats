#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    'declare __go_collected_file_paths' \
    '@go.collect_file_paths "$1"' \
    'printf "%s\n" "${__go_collected_file_paths[@]}"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: empty argument list does nothing" {
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: nonexistent directory path does nothing" {
  run "$TEST_GO_SCRIPT" ''
  assert_success ''
}

@test "$SUITE: directory with no regular files returns nothing" {
  mkdir -p "$TEST_GO_ROOTDIR/foo/bar/baz"
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success ''
}

@test "$SUITE: directory with a single file" {
  mkdir -p "$TEST_GO_ROOTDIR/foo/bar"
  printf '%s\n' 'baz' >"$TEST_GO_ROOTDIR/foo/bar/baz"
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success "$TEST_GO_ROOTDIR/foo/bar/baz"
}

@test "$SUITE: directory with several files" {
  mkdir -p "$TEST_GO_ROOTDIR/foo/"{bar,baz,quux}
  printf '%s\n' 'xyzzy' >"$TEST_GO_ROOTDIR/foo/bar/xyzzy"
  printf '%s\n' 'plugh' >"$TEST_GO_ROOTDIR/foo/baz/plugh"
  printf '%s\n' 'frobozz' >"$TEST_GO_ROOTDIR/foo/quux/frobozz"
  printf '%s\n' 'frotz' >"$TEST_GO_ROOTDIR/foo/frotz"
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success \
    "$TEST_GO_ROOTDIR/foo/bar/xyzzy" \
    "$TEST_GO_ROOTDIR/foo/baz/plugh" \
    "$TEST_GO_ROOTDIR/foo/frotz" \
    "$TEST_GO_ROOTDIR/foo/quux/frobozz"
}
