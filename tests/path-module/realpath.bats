#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/path"

setup() {
  test_filter
}

teardown() {
  @go.remove_test_go_rootdir
}

run_realpath() {
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "path"' \
    '@go.realpath "result" "$1"' \
    "if [[ \"\$PWD\" != '$TEST_GO_ROOTDIR' ]]; then" \
    "  printf \"EXPECTED PWD: %s\n\" '$TEST_GO_ROOTDIR' >&2" \
    '  printf "ACTUAL PWD:   %s\n" "$PWD" >&2' \
    '  exit 1' \
    'fi' \
    'printf "%s\n" "$result"'

  cd -P "$TEST_GO_ROOTDIR" >/dev/null
  export REAL_TEST_GO_ROOTDIR="$PWD"
  cd - >/dev/null

  run "$TEST_GO_SCRIPT" "$1"      
}

@test "$SUITE: resolves current directory to PWD" {
  run_realpath '.'
  assert_success "$REAL_TEST_GO_ROOTDIR"
}

@test "$SUITE: resolves '..' to parent of PWD" {
  run_realpath '..'
  assert_success "${REAL_TEST_GO_ROOTDIR%/*}"
}

@test "$SUITE: leaves root directory unchanged" {
  run_realpath '/'
  assert_success '/'
}

@test "$SUITE: resolves relative parents of root to root" {
  run_realpath '//..///..////../////'
  assert_success '/'
}

@test "$SUITE: leaves nonexistent absolute directory unchanged" {
  run_realpath '/foo/bar'
  assert_success '/foo/bar'
}

@test "$SUITE: resolves nonexistent directory to child of PWD" {
  run_realpath 'foo/bar'
  assert_success "$REAL_TEST_GO_ROOTDIR/foo/bar"
}

@test "$SUITE: resolves nonexistent ./ directory to child of PWD" {
  run_realpath './foo/bar'
  assert_success "$REAL_TEST_GO_ROOTDIR/foo/bar"
}

@test "$SUITE: resolves '..' in a nonexistent directory" {
  run_realpath 'foo/bar/../baz'
  assert_success "$REAL_TEST_GO_ROOTDIR/foo/baz"
}

@test "$SUITE: resolves nonexistent absolute directory to itself" {
  run_realpath '/foo/bar'
  assert_success '/foo/bar'
}

@test "$SUITE: resolves directory symlinks" {
  skip_if_system_missing 'ln'
  if [[ "$OSTYPE" == 'msys' ]]; then
    skip "ln doesn't work like it normally does on MSYS2"
  fi

  local dir_from_orig_path
  local dir_from_symlink_path

  mkdir -p "$TEST_GO_ROOTDIR/foo"
  ln -s "$TEST_GO_ROOTDIR/foo" "$TEST_GO_ROOTDIR/bar"

  run_realpath "$TEST_GO_ROOTDIR/foo"
  assert_success
  dir_from_orig_path="$output"

  run_realpath "$TEST_GO_ROOTDIR/bar"
  assert_success
  dir_from_symlink_path="$output"
  assert_equal "$dir_from_orig_path" "$dir_from_symlink_path"
}

@test "$SUITE: resolves file symlinks" {
  skip_if_system_missing 'ln'
  if [[ "$OSTYPE" == 'msys' ]]; then
    skip "ln doesn't work like it normally does on MSYS2"
  fi

  local file_from_orig_path
  local file_from_symlink_path

  mkdir -p "$TEST_GO_ROOTDIR"
  printf 'foo\n' >"$TEST_GO_ROOTDIR/foo"
  ln -s "$TEST_GO_ROOTDIR/foo" "$TEST_GO_ROOTDIR/bar"
  ln -s 'bar' "$TEST_GO_ROOTDIR/baz"
  ln -s "$TEST_GO_ROOTDIR/baz" "$TEST_GO_ROOTDIR/quux"
  ln -s 'quux' "$TEST_GO_ROOTDIR/xyzzy"

  run_realpath "$TEST_GO_ROOTDIR/foo"
  assert_success
  file_from_orig_path="$output"

  run_realpath "$TEST_GO_ROOTDIR/bar"
  assert_success
  file_from_symlink_path="$output"
  assert_equal "$file_from_orig_path" "$file_from_symlink_path"
}
