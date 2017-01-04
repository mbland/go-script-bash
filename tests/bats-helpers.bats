#! /usr/bin/env bats

load environment

teardown() {
  remove_bats_test_dirs
}

@test "$SUITE: suite name" {
  assert_equal 'bats-helpers: suite name' "$BATS_TEST_DESCRIPTION" 'SUITE'
}

@test "$SUITE: BATS_TEST_ROOTDIR contains space" {
  assert_matches ' ' "$BATS_TEST_ROOTDIR" "BATS_TEST_ROOTDIR"
}

@test "$SUITE: {create,remove}_bats_test_dirs" {
  local test_dirs=('foo'
    'bar/baz'
    'quux/xyzzy'
    'quux/plugh'
  )
  local test_dir

  if [[ -d "$BATS_TEST_ROOTDIR" ]]; then
    fail "'$BATS_TEST_ROOTDIR' already exists"
  fi

  for test_dir in "${test_dirs[@]}"; do
    if [[ -d "$BATS_TEST_ROOTDIR/$test_dir" ]]; then
      fail "'$test_dir' already present in '$BATS_TEST_ROOTDIR'"
    fi
  done

  run create_bats_test_dirs "${test_dirs[@]}"
  assert_success

  for test_dir in "${test_dirs[@]}"; do
    if [[ ! -d "$BATS_TEST_ROOTDIR/$test_dir" ]]; then
      fail "Failed to create '$test_dir' in '$BATS_TEST_ROOTDIR'"
    fi
  done

  run remove_bats_test_dirs
  assert_success

  if [[ -d "$BATS_TEST_ROOTDIR" ]]; then
    fail "Failed to remove '$BATS_TEST_ROOTDIR'"
  fi
}

@test "$SUITE: create_bats_test_script errors if no args" {
  run create_bats_test_script
  assert_failure 'No test script specified'
}

@test "$SUITE: create_bats_test_script creates Bash script" {
  if [[ -d "$BATS_TEST_ROOTDIR" ]]; then
    fail "'$BATS_TEST_ROOTDIR' already exists"
  fi

  run create_bats_test_script test-script \
    'echo Hello, World!'
  assert_success
  assert_file_equals "$BATS_TEST_ROOTDIR/test-script" \
    '#! /usr/bin/env bash' \
    'echo Hello, World!'

  if [[ ! -x "$BATS_TEST_ROOTDIR/test-script" ]]; then
    fail "Failed to make the test script executable"
  fi
}

@test "$SUITE: create_bats_test_script creates Perl script" {
  run create_bats_test_script test-script \
    '#! /usr/bin/env perl' \
    'printf "Hello, World!\n";'
  assert_success
  assert_file_equals "$BATS_TEST_ROOTDIR/test-script" \
    '#! /usr/bin/env perl' \
    'printf "Hello, World!\n";'
}

@test "$SUITE: create_bats_test_script automatically creates parent dirs" {
  if [[ -d "$BATS_TEST_ROOTDIR/foo/bar" ]]; then
    fail "'$BATS_TEST_ROOTDIR/foo/bar' already exists"
  fi

  run create_bats_test_script foo/bar/test-script \
    'echo Hello, World!'
  assert_success
  assert_file_equals "$BATS_TEST_ROOTDIR/foo/bar/test-script" \
    '#! /usr/bin/env bash' \
    'echo Hello, World!'
}

@test "$SUITE: fs_missing_permission_support" {
  local expected_result='false'

  # On some Windows file systems, any file starting with '#!' will be marked
  # executable. This is how we can tell Unix-style permissions aren't supported,
  # and thus some test conditions can't be created.
  run create_bats_test_script test-script 'echo Hello, World!'
  chmod 600 "$BATS_TEST_ROOTDIR/test-script"
  run fs_missing_permission_support

  if [[ -x "$BATS_TEST_ROOTDIR/test-script" ]]; then
    assert_success
  else
    assert_failure
  fi
}

@test "$SUITE: skip_if_cannot_trigger_file_permission_failure" {
  if fs_missing_file_permission_support; then
    skip_if_cannot_trigger_file_permission_failure
    fail "Should have skipped this test due to missing file permission support"
  elif [[ "$EUID" -eq '0' ]]; then
    skip_if_cannot_trigger_file_permission_failure
    fail "Should have skipped this test due to running as the superuser"
  fi
}
