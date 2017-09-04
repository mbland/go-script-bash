#! /usr/bin/env bats

load ../../environment

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "fileutil"' \
    '_@go.parse_copy_files_safely_args "$@"' \
    'for var_name in "${!__go_@}"; do' \
    '  case "${var_name#__go_}" in' \
    '  dir_mode|diff_files_args|src_files)' \
    '    array_name="${var_name}[*]"' \
    '    printf "%s: %s\n" "$var_name" "${!array_name}"' \
    '    ;;' \
    '  *)' \
    '    printf "%s: %s\n" "$var_name" "${!var_name}"' \
    '    ;;' \
    '  esac' \
    'done'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: sets nothing when args empty" {
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: sets canonicalized real path of --src-dir relative to PWD" {
  run "$TEST_GO_SCRIPT" '--src-dir' 'foo/bar/../baz'
  assert_success "__go_src_dir: $TEST_GO_ROOTDIR/foo/baz"
}

@test "$SUITE: sets --dir-mode" {
  run "$TEST_GO_SCRIPT" '--dir-mode' '755'
  assert_success '__go_dir_mode: --mode 755'
}

@test "$SUITE: sets --file-mode" {
  run "$TEST_GO_SCRIPT" '--file-mode' '644'
  assert_success '__go_file_mode: 644'
}

@test "$SUITE: sets --edit" {
  run "$TEST_GO_SCRIPT" '--edit'
  assert_success '__go_diff_files_args: --edit'
}

@test "$SUITE: sets --verbose" {
  run "$TEST_GO_SCRIPT" '--verbose'
  assert_success '__go_verbose: true'
}

@test "$SUITE: sets dest dir only relative to PWD" {
  run "$TEST_GO_SCRIPT" 'dest_dir'
  assert_success \
    "__go_dest_dir: $TEST_GO_ROOTDIR/dest_dir" \
    '__go_src_files: '
}

@test "$SUITE: sets single src file and dest dir" {
  run "$TEST_GO_SCRIPT" 'foo/bar' 'dest_dir'
  assert_success \
    "__go_dest_dir: $TEST_GO_ROOTDIR/dest_dir" \
    '__go_src_files: foo/bar'
}

@test "$SUITE: sets multiple src files and dest dir" {
  run "$TEST_GO_SCRIPT" 'foo/bar' 'baz/quux' 'xyzzy/plugh' 'dest_dir'
  assert_success \
    "__go_dest_dir: $TEST_GO_ROOTDIR/dest_dir" \
    '__go_src_files: foo/bar baz/quux xyzzy/plugh'
}

@test "$SUITE: sets everything at once" {
  run "$TEST_GO_SCRIPT" \
    '--verbose' \
    '--edit' \
    '--file-mode' '644' \
    '--dir-mode' '755' \
    '--src-dir' 'foo/bar/../baz' \
    'foo/bar' 'baz/quux' 'xyzzy/plugh' 'dest_dir'
  assert_success
  assert_lines_equal \
    "__go_dest_dir: $TEST_GO_ROOTDIR/dest_dir" \
    '__go_diff_files_args: --edit' \
    '__go_dir_mode: --mode 755' \
    '__go_file_mode: 644' \
    "__go_src_dir: $TEST_GO_ROOTDIR/foo/baz" \
    '__go_src_files: foo/bar baz/quux xyzzy/plugh' \
    '__go_verbose: true'
}
