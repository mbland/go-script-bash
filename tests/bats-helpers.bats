#! /usr/bin/env bats

load environment

setup() {
  test_filter
}

teardown() {
  remove_bats_test_dirs
}

@test "$SUITE: suite name" {
  assert_equal 'bats-helpers: suite name' "$BATS_TEST_DESCRIPTION" 'SUITE'
}

@test "$SUITE: BATS_TEST_ROOTDIR contains space" {
  assert_matches ' ' "$BATS_TEST_ROOTDIR" "BATS_TEST_ROOTDIR"
}

check_dirs_do_not_exist() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  __check_dirs_do_not_exist "$@"
  restore_bats_shell_options "$?"
}

__check_dirs_do_not_exist() {
  local test_dir

  for test_dir in "$@"; do
    if [[ -d "$BATS_TEST_ROOTDIR/$test_dir" ]]; then
      printf "'$test_dir' already present in '$BATS_TEST_ROOTDIR'\n" >&2
      return 1
    fi
  done
}

check_dirs_exist() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  __check_dirs_exist "$@"
  restore_bats_shell_options "$?"
}

__check_dirs_exist() {
  local test_dir

  for test_dir in "${test_dirs[@]}"; do
    if [[ ! -d "$BATS_TEST_ROOTDIR/$test_dir" ]]; then
      printf "Failed to create '$test_dir' in '$BATS_TEST_ROOTDIR'\n" >&2
      return 1
    fi
  done
}

@test "$SUITE: {create,remove}_bats_test_dirs" {
  local test_dirs=('foo'
    'bar/baz'
    'quux/xyzzy'
    'quux/plugh'
  )

  if [[ -d "$BATS_TEST_ROOTDIR" ]]; then
    fail "'$BATS_TEST_ROOTDIR' already exists"
  fi
  check_dirs_do_not_exist "${test_dirs[@]}"

  run create_bats_test_dirs "${test_dirs[@]}"
  assert_success
  check_dirs_exist "${test_dirs[@]}"

  run remove_bats_test_dirs
  assert_success

  if [[ -d "$BATS_TEST_ROOTDIR" ]]; then
    fail "Failed to remove '$BATS_TEST_ROOTDIR'"
  fi
}

@test "$SUITE: create_bats_test_script errors if no args" {
  run create_bats_test_script
  assert_failure 'No test script name or path specified'
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
  create_bats_test_script test-script 'echo Hello, World!'
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

@test "$SUITE: skip if system missing" {
  create_bats_test_script 'test.bats' \
    '#! /usr/bin/env bats' \
    ". '$_GO_CORE_DIR/lib/bats/helpers'" \
    '@test "skip if missing" { skip_if_system_missing foo bar baz; }'

  stub_program_in_path 'foo'
  stub_program_in_path 'bar'
  stub_program_in_path 'baz'

  run bats "$BATS_TEST_ROOTDIR/test.bats"
  assert_success
  assert_lines_equal '1..1' \
    'ok 1 skip if missing'

  rm "$BATS_TEST_BINDIR"/*
  run "$BATS_TEST_ROOTDIR/test.bats"
  assert_success
  assert_lines_equal '1..1' \
    'ok 1 # skip (foo, bar, baz not installed on the system) skip if missing'
}

@test "$SUITE: test_join fails if result variable name is invalid" {
  create_bats_test_script test-script \
    ". '$_GO_CORE_DIR/lib/bats/helpers'" \
    "test_join ',' '3foobar'"
  run "$BATS_TEST_ROOTDIR/test-script"
  assert_failure '"3foobar" is not a valid variable identifier.'
}

@test "$SUITE: test_join succeeds" {
  create_bats_test_script test-script \
    ". '$_GO_CORE_DIR/lib/bats/helpers'" \
    "declare result" \
    "test_join ',' 'result' '--foo' 'bar' 'baz' 'This \"%/\" is from #98.'" \
    "printf '%s\n' \"\$result\""
  run "$BATS_TEST_ROOTDIR/test-script"
  assert_success '--foo,bar,baz,This "%/" is from #98.'
}

@test "$SUITE: test_printf" {
  create_bats_test_script test-script \
    "test_printf '%s\n' 'some test debug output'"

  run "$BATS_TEST_ROOTDIR/test-script"
  assert_success ''
  TEST_DEBUG='true' run "$BATS_TEST_ROOTDIR/test-script"
  assert_success 'some test debug output'
}

@test "$SUITE: test_filter" {
  # We have to define the script as an array, or the main Bats process will try
  # to parse it.
  local test_file="$BATS_TEST_ROOTDIR/test.bats"
  local test_script=('#! /usr/bin/env bats'
    "load '$_GO_CORE_DIR/lib/bats/helpers'"
    'setup() { test_filter; }'
    '@test "foo" { :; }'
    '@test "bar" { :; }'
    '@test "baz" { :; }')

  create_bats_test_script "${test_file#$BATS_TEST_ROOTDIR/}" "${test_script[@]}"

  TEST_FILTER= run bats "$test_file"
  assert_success
  assert_lines_equal '1..3' \
    'ok 1 foo' \
    'ok 2 bar' \
    'ok 3 baz'

  TEST_FILTER='b[a-z]r' run bats "$test_file"
  assert_success
  assert_lines_equal '1..3' \
    'ok 1 # skip foo' \
    'ok 2 bar' \
    'ok 3 # skip baz'
}

@test "$SUITE: split_bats_output_into_lines" {
  # Bats will still trim traling newlines from `output`, so don't include them.
  local test_output=$'\n\nfoo\n\nbar\n\nbaz'
  run printf "$test_output"
  assert_success "$test_output"
  assert_lines_equal 'foo' 'bar' 'baz'
  split_bats_output_into_lines
  assert_lines_equal '' '' 'foo' '' 'bar' '' 'baz'
}

@test "$SUITE: {stub,restore}_program_in_path for stubbing external programs" {
  skip_if_system_missing 'cp'

  local bats_bindir_pattern="^${BATS_TEST_BINDIR}:"
  local cp_orig_path="$(command -v cp)"
  local modified_search_path
  local cp_stub_path

  fail_if matches "$bats_bindir_pattern" "$PATH"
  stub_program_in_path 'cp' 'echo "$@"'
  modified_search_path="$PATH"
  cp_stub_path="$(command -v 'cp')"

  run cp foo.txt bar.txt baz.txt
  restore_program_in_path 'cp'
  assert_success 'foo.txt bar.txt baz.txt'

  assert_matches "$bats_bindir_pattern" "$modified_search_path"
  fail_if matches "$bats_bindir_pattern" "$PATH"
  assert_equal "$cp_orig_path" "$(command -v 'cp')"
}

@test "$SUITE: {stub,restore}_program_in_path trigger Bash command rehash" {
  # `restore_program_in_path` unconditionally updates `PATH`, which resets
  # Bash's executable path hash table. I didn't realize this until calling
  # `stub_program_in_path` on `rm` and finding that the `rm` stub was only found
  # when it was the first in a series of programs to be stubbed. After some
  # trial and error, I realized this was because the `create_bats_test_script`
  # call invokes `rm` and `stub_program_in_path` only modifies `PATH` on the
  # first call.
  #
  # This isn't documented in the Bash man page, but once I figured out what was
  # happening, my hypothesis was confirmed by: https://superuser.com/a/1000317
  #
  # Hence, this test case is more for `stub_program_in_path` than `restore`.
  skip_if_system_missing 'cp'

  local cp_orig_path="$(command -v cp)"
  local cp_stub_path

  # This `PATH` update prevents `stub_program_in_path` from assigning to `PATH`
  # and resetting the executable hash table.
  export PATH="$BATS_TEST_BINDIR:$PATH"

  # This now primes the hash table to return the original path for `cp` when
  # queried by `command -v cp`.
  hash "cp"

  stub_program_in_path 'cp'
  cp_stub_path="$(command -v 'cp')"
  restore_program_in_path 'cp'

  # `stub_program_in_path` should've explicitly called `hash` on the stub so
  # that the `command -v cp` invocation above returned its path.
  assert_equal "$BATS_TEST_BINDIR/cp" "$cp_stub_path"

  # `restore_program_in_path` should've updated `PATH` to clear the hash table
  # so that `command -v cp` now returns the original path.
  assert_equal "$cp_orig_path" "$(command -v 'cp')"
}

@test "$SUITE: restore_program_in_path fails when stub doesn't exist" {
  run restore_program_in_path 'foobar'
  assert_failure "Bats test stub program doesn't exist: foobar"
}

@test "$SUITE: restore_program_in_path fails when not provided an argument" {
  run restore_program_in_path
  assert_failure 'No command name provided.'
}

@test "$SUITE: create_forwarding_script does nothing if program doesn't exist" {
  create_forwarding_script 'some-noexistent-program-name'
  fail_if matches "^${BATS_TEST_BINDIR}:" "$PATH"
  run command -v 'some-noexistent-program-name'
  assert_failure
}

@test "$SUITE: find forwarding script with PATH=\$BATS_TEST_BINDIR" {
  create_forwarding_script 'bash'
  PATH="$BATS_TEST_BINDIR" run command -v 'bash'
  assert_success "$BATS_TEST_BINDIR/bash"
}
