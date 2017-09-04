#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    '@go.create_dirs "$@"'
}

teardown() {
  @go.remove_test_go_rootdir
}

assert_dirs_created() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  local result='0'
  local missing_dirs=()
  local dir

  for dir in "$@"; do
    if [[ ! -d "$TEST_GO_ROOTDIR/$dir" ]]; then
      missing_dirs+=("$dir")
    fi
  done

  if [[ "${#missing_dirs[@]}" -ne '0' ]]; then
    printf 'The following directories were not created:\n' >&2
    printf '  %s\n' "${missing_dirs[@]}" >&2
    result='1'
  fi
  restore_bats_shell_options "$result"
}

@test "$SUITE: empty directory list does nothing" {
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: empty directory creates FATAL error" {
  run "$TEST_GO_SCRIPT" ''
  assert_failure
  assert_line_matches '0' \
    'FATAL.* The empty string is not a valid directory name'
}

@test "$SUITE: existing directory does nothing" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR"
  assert_success ''
}

@test "$SUITE: new single directory" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success ''
  assert_dirs_created 'foo'
}

@test "$SUITE: permissions set for all new directories" {
  skip_if_cannot_trigger_file_permission_failure
  local existing_parent="$TEST_GO_ROOTDIR/foo"
  mkdir -p "$existing_parent"
  chmod 700 "$existing_parent"

  run "$TEST_GO_SCRIPT" --mode 723 "$TEST_GO_ROOTDIR/foo/bar/baz"
  assert_success ''
  assert_dirs_created 'foo'

  run ls -ld "$TEST_GO_ROOTDIR/"{foo,foo/bar,foo/bar/baz}
  assert_success
  assert_lines_match '^drwx------' '^drwx-w--wx' '^drwx-w--wx'
}

@test "$SUITE: multiple calls are idempotent" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success ''
  assert_dirs_created 'foo'

  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo"
  assert_success ''
}

@test "$SUITE: permissions don't change if directory already exists" {
  skip_if_cannot_trigger_file_permission_failure
  mkdir -p "$TEST_GO_ROOTDIR/foo"
  chmod 700 "$TEST_GO_ROOTDIR/foo"

  run "$TEST_GO_SCRIPT" --mode 723 "$TEST_GO_ROOTDIR/foo"
  assert_success ''

  run ls -ld "$TEST_GO_ROOTDIR/foo"
  assert_success
  assert_output_matches '^drwx------'
}

@test "$SUITE: multiple directories" {
  local dirs=('foo' 'bar/baz' 'bar/quux' 'xyzzy/plugh/frobozz')

  run "$TEST_GO_SCRIPT" "${dirs[@]#$TEST_GO_ROOTDIR/}"
  assert_success ''
  assert_dirs_created "${dirs[@]}"
}

@test "$SUITE: existing non-directory creates a FATAL error" {
  mkdir -p "$TEST_GO_ROOTDIR/foo"
  printf 'bar\n' >"$TEST_GO_ROOTDIR/foo/bar"

  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo/bar/baz"
  assert_failure
  assert_line_matches '0' \
    "FATAL.* $TEST_GO_ROOTDIR/foo/bar exists and is not a directory"
}

@test "$SUITE: mkdir failure is a FATAL error" {
  local existing_parent="$TEST_GO_ROOTDIR/foo"
  mkdir -p "$existing_parent"
  stub_program_in_path 'mkdir' 'exit 1'

  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/foo/bar/baz"
  restore_program_in_path 'mkdir'
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Could not create $TEST_GO_ROOTDIR/foo/bar/baz in $existing_parent"
}

@test "$SUITE: chmod failure is a FATAL error" {
  local existing_parent="$TEST_GO_ROOTDIR/foo"
  mkdir -p "$existing_parent"
  stub_program_in_path 'chmod' 'exit 1'

  run "$TEST_GO_SCRIPT" --mode 700 "$TEST_GO_ROOTDIR/foo/bar/baz"
  restore_program_in_path 'chmod'
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Could not set permissions for $existing_parent/bar"
}
