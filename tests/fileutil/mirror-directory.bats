#! /usr/bin/env bats

load ../environment

SRC_DIR="$TEST_GO_ROOTDIR/src"
DEST_DIR="$TEST_GO_ROOTDIR/dest"
TEST_FILES=

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    '@go.mirror_directory "$@"'
  mkdir -p "$SRC_DIR"
  TEST_FILES=('foo' 'bar' 'baz')
}

teardown() {
  @go.remove_test_go_rootdir
}

create_test_source_files() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  printf '%s\n' 'foo' >"$SRC_DIR/foo"
  printf '%s\n' 'bar' >"$SRC_DIR/bar"
  printf '%s\n' 'baz' >"$SRC_DIR/baz"
  restore_bats_shell_options
}

validate_test_dest_dir() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  _validate_test_dest_dir
  restore_bats_shell_options "$?"
}

_validate_test_dest_dir() {
  local f
  local result='0'

  for f in "${TEST_FILES[@]}"; do
    if [[ ! -f "$DEST_DIR/$f" ]]; then
      printf 'Failed to create: %s\n' "$DEST_DIR/$f" >&2
      result='1'
    fi
  done

  if [[ "$result" != '0' ]]; then
    printf '\nCONTENTS OF %s:\n' "$TEST_GO_ROOTDIR" >&2
    ls -lR "$TEST_GO_ROOTDIR" >&2
  fi
  return "$result"
}

@test "$SUITE: mirrors specific files from one directory to another" {
  skip_if_system_missing 'tar'
  create_test_source_files
  mkdir -p "$DEST_DIR"

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  assert_success
  validate_test_dest_dir
}

@test "$SUITE: creates destination directory if it doesn't exist" {
  skip_if_system_missing 'tar'
  create_test_source_files

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  assert_success
  validate_test_dest_dir
}

@test "$SUITE: only copy selected files" {
  skip_if_system_missing 'tar'
  local ignored_file="$DEST_DIR/${TEST_FILES[1]}"

  unset 'TEST_FILES[1]'
  create_test_source_files

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR" "${TEST_FILES[@]}"
  assert_success
  validate_test_dest_dir

  if [[ -f "$ignored_file" ]]; then
    fail "$ignored_file copied to destination when it should've been ignored"
  fi
}

@test "$SUITE: logs FATAL if the source directory doesn't exist" {
  rmdir "$SRC_DIR"
  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  assert_failure
  assert_output_matches "FATAL.* Source directory $SRC_DIR doesn't exist"
}

@test "$SUITE: logs FATAL if the destination directory can't be created" {
  create_test_source_files
  stub_program_in_path 'mkdir' \
    'exit 1'

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  restore_program_in_path 'mkdir'
  assert_failure
  assert_output_matches \
    "FATAL.* Failed to create destination directory $DEST_DIR"
}

@test "$SUITE: logs FATAL if the input tar fails" {
  stub_program_in_path 'tar' \
    'if [[ "$1" == "-cf" ]]; then' \
    '  printf "CREATE FAILED\n" >&2' \
    '  exit 1' \
    'fi' \

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  restore_program_in_path 'tar'
  assert_failure
  assert_line_matches '0' 'CREATE FAILED'
  assert_line_matches '1' \
    "FATAL.* Failed to mirror files from $SRC_DIR to $DEST_DIR"
}

@test "$SUITE: logs FATAL if the output tar fails" {
  stub_program_in_path 'tar' \
    'if [[ "$1" == "-xf" ]]; then' \
    '  printf "EXTRACT FAILED\n" >&2' \
    '  exit 1' \
    'fi'

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  restore_program_in_path 'tar'
  assert_failure
  assert_line_matches '0' 'EXTRACT FAILED'
  assert_line_matches '1' \
    "FATAL.* Failed to mirror files from $SRC_DIR to $DEST_DIR"

}

@test "$SUITE: logs FATAL if the real source and dest dirs are the same" {
  skip_if_system_missing 'ln'
  if [[ "$OSTYPE" == 'msys' ]]; then
    skip "ln doesn't work like it normally does on MSYS2"
  fi

  local same_dir="$TEST_GO_ROOTDIR/same-dir"

  . "$_GO_USE_MODULES" 'path'
  @go.realpath 'same_dir' "$same_dir"

  # Remove SRC_DIR so the link isn't created inside SRC_DIR, but replaces it.
  rmdir "$SRC_DIR"
  ln -s "$same_dir" "$SRC_DIR"
  ln -s "$same_dir" "$DEST_DIR"

  run "$TEST_GO_SCRIPT" "$SRC_DIR" "$DEST_DIR"
  assert_failure
  assert_line_matches '0' \
    'FATAL.* Real source and destination dirs are the same:' \
  assert_line_matches '1' "  source: $SRC_DIR"
  assert_line_matches '2' "  dest:   $DEST_DIR"
  assert_line_matches '3' "  real:   $same_dir"
}
