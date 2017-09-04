#! /usr/bin/env bats

load ../../environment

SRC_DIR=

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    '_@go.set_source_files_for_copy_files_safely "$@"' \
    'result="$?"' \
    'for var_name in "${!__go_@}"; do' \
    '  case "${var_name#__go_}" in' \
    '  src_files|source_file_errors)' \
    '    printf "%s:\n" "$var_name"' \
    '    array_name="${var_name}[@]"' \
    '    for item in "${!array_name}"; do' \
    '      printf "  %s\n" "$item"' \
    '    done' \
    '    ;;' \
    '  *)' \
    '    printf "%s: %s\n" "$var_name" "${!var_name}"' \
    '    ;;' \
    '  esac' \
    'done' \
    'exit "$result"'

  SRC_DIR="$TEST_GO_ROOTDIR/src"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: sets __go_src_dir to PWD when not set" {
  run "$TEST_GO_SCRIPT"
  assert_success \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:'
}

@test "$SUITE: sets no files when __go_src_dir doesn't exist" {
  __go_src_dir="$SRC_DIR" run "$TEST_GO_SCRIPT"
  assert_success "__go_src_dir: $SRC_DIR" \
    '__go_src_files:'
}

@test "$SUITE: sets no files when __go_src_dir contains no files" {
  mkdir -p "$SRC_DIR/"{foo,bar/baz,quux/xyzzy/plugh}

  __go_src_dir="$SRC_DIR" run "$TEST_GO_SCRIPT"
  assert_success "__go_src_dir: $SRC_DIR" \
    '__go_src_files:'
}

@test "$SUITE: collects relative file paths from __go_src_dir when args empty" {
  mkdir -p "$SRC_DIR/"{foo,bar,quux/xyzzy,frobozz}
  printf '%s\n' 'baz' >"$SRC_DIR/bar/baz"
  printf '%s\n' 'plugh' >"$SRC_DIR/quux/xyzzy/plugh"
  printf '%s\n' 'frotz' >"$SRC_DIR/frobozz/frotz"

  __go_src_dir="$SRC_DIR" run "$TEST_GO_SCRIPT"
  assert_success \
    "__go_src_dir: $SRC_DIR" \
    '__go_src_files:' \
    '  bar/baz' \
    '  frobozz/frotz' \
    '  quux/xyzzy/plugh'
}

@test "$SUITE: validates relative file path args against __go_src_dir" {
  mkdir -p "$SRC_DIR/"{foo,bar,quux/xyzzy,frobozz}
  printf '%s\n' 'baz' >"$SRC_DIR/bar/baz"
  printf '%s\n' 'plugh' >"$SRC_DIR/quux/xyzzy/plugh"
  printf '%s\n' 'frotz' >"$SRC_DIR/frobozz/frotz"

  # Note that it omits any args not provided as arguments.
  __go_src_dir="$SRC_DIR" run "$TEST_GO_SCRIPT" 'bar/baz' 'quux/xyzzy/plugh'
  assert_success \
    "__go_src_dir: $SRC_DIR" \
    '__go_src_files:' \
    '  bar/baz' \
    '  quux/xyzzy/plugh'
}

@test "$SUITE: passes through absolute paths into __go_src_dir" {
  mkdir -p "$SRC_DIR/"{foo,bar,quux/xyzzy,frobozz}
  printf '%s\n' 'baz' >"$SRC_DIR/bar/baz"
  printf '%s\n' 'plugh' >"$SRC_DIR/quux/xyzzy/plugh"
  printf '%s\n' 'frotz' >"$SRC_DIR/frobozz/frotz"

  # Note that it omits any args not provided as arguments.
  __go_src_dir="$SRC_DIR" run \
    "$TEST_GO_SCRIPT" "$SRC_DIR/bar/baz" "$SRC_DIR/quux/xyzzy/plugh"

  assert_success \
    "__go_src_dir: $SRC_DIR" \
    '__go_src_files:' \
    "  $SRC_DIR/bar/baz" \
    "  $SRC_DIR/quux/xyzzy/plugh"
}

@test "$SUITE: passes through absolute paths not in __go_src_dir" {
  mkdir -p "$SRC_DIR/"{foo,bar,quux/xyzzy,frobozz}
  printf '%s\n' 'baz' >"$SRC_DIR/bar/baz"
  printf '%s\n' 'plugh' >"$SRC_DIR/quux/xyzzy/plugh"
  printf '%s\n' 'frotz' >"$SRC_DIR/frobozz/frotz"

  __go_src_dir="$SRC_DIR/quux" run "$TEST_GO_SCRIPT" \
    "$SRC_DIR/bar/baz" "$SRC_DIR/quux/xyzzy/plugh" "$SRC_DIR/frobozz/frotz"

  assert_success \
    "__go_src_dir: $SRC_DIR/quux" \
    '__go_src_files:' \
    "  $SRC_DIR/bar/baz" \
    "  $SRC_DIR/quux/xyzzy/plugh" \
    "  $SRC_DIR/frobozz/frotz"
}

@test "$SUITE: canonicalizes paths containing . and .." {
  mkdir -p "$TEST_GO_ROOTDIR"
  printf '%s\n' 'foo' >"$TEST_GO_ROOTDIR/foo"

  run "$TEST_GO_SCRIPT" 'bar/./../foo/.'
  assert_success \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:' \
    "  foo"
}

@test "$SUITE: a source path matching __go_src_dir causes an error" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR"
  assert_failure \
    '__go_source_file_errors:' \
    "  The --src-dir can't be a file path argument" \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:'
}

@test "$SUITE: an empty file path causes an error" {
  run "$TEST_GO_SCRIPT" ''
  assert_failure \
    '__go_source_file_errors:' \
    "  The empty string isn't a valid file name" \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:'
}

@test "$SUITE: file paths producing parents of __go_src_dir become absolute" {
  mkdir -p "$SRC_DIR" "$TEST_GO_ROOTDIR/baz"
  printf '%s\n' 'bar' >"$TEST_GO_ROOTDIR/bar"
  printf '%s\n' 'quux' >"$TEST_GO_ROOTDIR/baz/quux"

  __go_src_dir="$SRC_DIR" run "$TEST_GO_SCRIPT" 'foo/../../bar' '../baz/quux'
  assert_success \
    "__go_src_dir: $SRC_DIR" \
    '__go_src_files:' \
    "  $TEST_GO_ROOTDIR/bar" \
    "  $TEST_GO_ROOTDIR/baz/quux"
}

@test "$SUITE: nonexistent file path causes an error" {
  run "$TEST_GO_SCRIPT" 'foo'
  assert_failure \
    '__go_source_file_errors:' \
    "  File does not exist: $TEST_GO_ROOTDIR/foo" \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:'
}

@test "$SUITE: a file path that isn't a regular file causes an error" {
  local dir_path="$TEST_GO_ROOTDIR/foo"
  mkdir -p "$dir_path"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_failure \
    '__go_source_file_errors:' \
    "  Path is not a regular file: $dir_path" \
    "__go_src_dir: $TEST_GO_ROOTDIR" \
    '__go_src_files:'
}
