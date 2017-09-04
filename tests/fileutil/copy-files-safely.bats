#! /usr/bin/env bats

load ../environment

SRC_DIR=
DEST_DIR=

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    '@go.copy_files_safely "$@"'

  SRC_DIR="$TEST_GO_ROOTDIR/src"
  DEST_DIR="$TEST_GO_ROOTDIR/dest"
  mkdir -p "$SRC_DIR" "$DEST_DIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: empty argument list does nothing" {
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: log FATAL on source file errors" {
  run "$TEST_GO_SCRIPT" '' 'bogus'
  assert_failure
  assert_line_matches '0' 'FATAL.* Source file list contains errors:'
  assert_line_equals  '1' "  The empty string isn't a valid file name"
}

@test "$SUITE: log FATAL on empty source file list when dest_dir specified" {
  run "$TEST_GO_SCRIPT" 'bogus'
  assert_failure
  assert_line_matches '0' 'FATAL.* No source files specified'
}

@test "$SUITE: log FATAL on empty dest_dir when source files specified" {
  printf '%s\n' 'foo' >"$SRC_DIR/foo"

  run "$TEST_GO_SCRIPT" --src-dir "$SRC_DIR"
  assert_failure
  assert_line_matches '0' 'FATAL.* No destination directory specified'
}

@test "$SUITE: does nothing if a file already exists" {
  printf 'foo\n' >"$SRC_DIR/foo"
  printf 'foo\n' >"$DEST_DIR/foo"

  run "$TEST_GO_SCRIPT" "$SRC_DIR/foo" "$DEST_DIR"
  assert_success ''
}

@test "$SUITE: warns if a file already exists and is different" {
  skip_if_system_missing diff
  printf 'foo\n' >"$SRC_DIR/foo"
  printf 'bar\n' >"$DEST_DIR/foo"

  run "$TEST_GO_SCRIPT" "$SRC_DIR/foo" "$DEST_DIR"
  assert_failure
  assert_lines_match "^WARN.* $SRC_DIR/foo differs from $DEST_DIR/foo\$"
}

@test "$SUITE: --edit opens _GO_DIFF_EDITOR if an existing file is different" {
  skip_if_system_missing diff
  printf 'foo\n' >"$SRC_DIR/foo"
  printf 'bar\n' >"$DEST_DIR/foo"
  stub_program_in_path 'vimdiff' \
    'printf "%s\n" "LHS: $1" "RHS: $2"'

  _GO_DIFF_EDITOR='vimdiff' run "$TEST_GO_SCRIPT" --edit \
    "$SRC_DIR/foo" "$DEST_DIR"
  restore_program_in_path 'vimdiff'

  assert_failure
  assert_lines_match \
    "^WARN.* $SRC_DIR/foo differs from $DEST_DIR/foo\$" \
    "^INFO.* Editing $SRC_DIR/foo and $DEST_DIR/foo\$" \
    "LHS: $SRC_DIR/foo" \
    "RHS: $DEST_DIR/foo"
}

@test "$SUITE: logs FATAL if the destination exists and isn't a regular file" {
  printf 'foo\n' >"$SRC_DIR/foo"
  mkdir "$DEST_DIR/foo"

  run "$TEST_GO_SCRIPT" "$SRC_DIR/foo" "$DEST_DIR"
  assert_failure
  assert_line_matches '0' \
    "^FATAL.* $DEST_DIR/foo exists but isn't a regular file"
}

@test "$SUITE: creates a new file with verbose output" {
  printf 'foo\n' >"$SRC_DIR/foo"

  run "$TEST_GO_SCRIPT" --verbose "$SRC_DIR/foo" "$DEST_DIR"
  assert_success
  assert_lines_match "^INFO.* Copying $SRC_DIR/foo => $DEST_DIR/foo\$"
}

@test "$SUITE: sets permissions for new directories and destination file" {
  skip_if_cannot_trigger_file_permission_failure
  printf 'foo\n' >"$SRC_DIR/foo"
  rmdir "$DEST_DIR"

  run "$TEST_GO_SCRIPT" --dir-mode 723 --file-mode 200 \
    "$SRC_DIR/foo" "$DEST_DIR"
  assert_success ''

  run ls -ld "$DEST_DIR/"{,foo}
  assert_success
  assert_lines_match '^drwx-w--wx' '^--w-------'
}

@test "$SUITE: logs FATAL if copy fails" {
  printf 'foo\n' >"$SRC_DIR/foo"
  stub_program_in_path 'cp' 'exit 1'

  run "$TEST_GO_SCRIPT" "$SRC_DIR/foo" "$DEST_DIR"
  restore_program_in_path 'cp'
  assert_failure
  assert_line_matches '0' "FATAL.* Failed to copy $SRC_DIR/foo to $DEST_DIR/foo"
}

@test "$SUITE: logs FATAL if setting file permissions fails" {
  printf 'foo\n' >"$SRC_DIR/foo"
  stub_program_in_path 'chmod' 'exit 1'

  run "$TEST_GO_SCRIPT" --file-mode 600 "$SRC_DIR/foo" "$DEST_DIR"
  restore_program_in_path 'chmod'
  assert_failure
  assert_line_matches '0' "FATAL.* Failed to set permissions on $DEST_DIR/foo"
}

@test "$SUITE: copies files directly into top-level when paths are absolute" {
  mkdir -p "$SRC_DIR/"{bar,quux/xyzzy}
  printf '0\n' >"$SRC_DIR/foo"
  printf '1\n' >"$SRC_DIR/bar/baz"
  printf '2\n' >"$SRC_DIR/quux/xyzzy/plugh"

  run "$TEST_GO_SCRIPT" --src-dir "$SRC_DIR" --verbose \
    "$SRC_DIR/foo" \
    "$SRC_DIR/bar/baz" \
    "$SRC_DIR/quux/xyzzy/plugh" \
    "$DEST_DIR"

  assert_success
  assert_lines_match \
    "INFO.* Copying $SRC_DIR/foo => $DEST_DIR/foo" \
    "INFO.* Copying $SRC_DIR/bar/baz => $DEST_DIR/baz" \
    "INFO.* Copying $SRC_DIR/quux/xyzzy/plugh => $DEST_DIR/plugh"
  assert_file_equals "$DEST_DIR/foo" '0'
  assert_file_equals "$DEST_DIR/baz" '1'
  assert_file_equals "$DEST_DIR/plugh" '2'
}

@test "$SUITE: preserves relative directories when paths are relative" {
  mkdir -p "$SRC_DIR/"{bar,quux/xyzzy}
  printf '0\n' >"$SRC_DIR/foo"
  printf '1\n' >"$SRC_DIR/bar/baz"
  printf '2\n' >"$SRC_DIR/quux/xyzzy/plugh"

  run "$TEST_GO_SCRIPT" --src-dir "$SRC_DIR" --verbose "$DEST_DIR"

  assert_success
  # Since we're relying on --src-dir without file arguments, the copies will
  # happen in lexicographic order.
  assert_lines_match \
    "INFO.* Copying $SRC_DIR/bar/baz => $DEST_DIR/bar/baz" \
    "INFO.* Copying $SRC_DIR/foo => $DEST_DIR/foo" \
    "INFO.* Copying $SRC_DIR/quux/xyzzy/plugh => $DEST_DIR/quux/xyzzy/plugh"
  assert_file_equals "$DEST_DIR/foo" '0'
  assert_file_equals "$DEST_DIR/bar/baz" '1'
  assert_file_equals "$DEST_DIR/quux/xyzzy/plugh" '2'
}
