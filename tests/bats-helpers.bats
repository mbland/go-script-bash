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

@test "$SUITE: skip_if_none_present_on_system" {
  stub_program_in_path 'quux'
  run_bats_test_suite_in_isolation 'skip-if-none-present-on-system-test.bats' \
    "load '$_GO_CORE_DIR/lib/bats/helpers'" \
    '@test "should not skip if at least one present" {' \
    '  skip_if_none_present_on_system foo bar baz quux' \
    '}'\
    '@test "single program missing" {' \
    '  skip_if_none_present_on_system foo' \
    '}' \
    '@test "two programs missing" {' \
    '  skip_if_none_present_on_system foo bar' \
    '}' \
    '@test "three programs missing" {' \
    '  skip_if_none_present_on_system foo bar baz' \
    '}'
  assert_success

  local expected_messages=("foo isn't installed on the system"
    'Neither foo nor bar is installed on the system'
    'None of foo, bar, or baz are installed on the system')
  assert_lines_equal '1..4' \
    'ok 1 should not skip if at least one present' \
    "ok 2 # skip (${expected_messages[0]}) single program missing" \
    "ok 3 # skip (${expected_messages[1]}) two programs missing" \
    "ok 4 # skip (${expected_messages[2]}) three programs missing"
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

@test "$SUITE: restore_programs_in_path restores multiple programs at once" {
  local orig_paths=($(command -v cp mkdir ls))
  stub_program_in_path 'cp'
  stub_program_in_path 'mkdir'
  stub_program_in_path 'ls'
  run command -v 'cp' 'mkdir' 'ls'
  assert_success "${BATS_TEST_BINDIR[@]}"/{cp,mkdir,ls}

  restore_programs_in_path 'cp' 'mkdir' 'ls'
  run command -v 'cp' 'mkdir' 'ls'
  assert_success "${orig_paths[@]}"
}

@test "$SUITE: restore_programs_in_path reports an error if no stub exists" {
  local orig_paths=($(command -v cp ls))
  stub_program_in_path 'cp'
  stub_program_in_path 'ls'
  run restore_programs_in_path 'cp' 'mkdir' 'ls'
  assert_failure "Bats test stub program doesn't exist: mkdir"

  # Since we ran `restore_programs_in_path` in a subshell via `run`, the Bash
  # executable path hash table in this process needs to be cleared manually.
  hash -r
  run command -v 'cp' 'ls'
  assert_success "${orig_paths[@]}"
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
  restore_program_in_path 'bash'
  assert_success "$BATS_TEST_BINDIR/bash"
}

@test "$SUITE: forwarding script has access to PATH with BATS_TEST_BINDIR" {
  create_forwarding_script 'bash'
  PATH="$BATS_TEST_BINDIR" run 'bash' '-c' 'echo $PATH'
  restore_program_in_path 'bash'
  assert_success "$BATS_TEST_BINDIR:$PATH"
}

@test "$SUITE: forwarding script has PATH defined by a parameter" {
  local path='/bin:/usr/bin'

  create_forwarding_script --path "$path" 'bash'
  PATH="$BATS_TEST_BINDIR" run 'bash' '-c' 'echo $PATH'
  restore_program_in_path 'bash'
  assert_success "$BATS_TEST_BINDIR:$path"
}

@test "$SUITE: forwarding script sets PATH to BATS_TEST_BINDIR when arg empty" {
  create_forwarding_script --path '' 'bash'
  PATH="$BATS_TEST_BINDIR" run 'bash' '-c' 'echo $PATH'
  restore_program_in_path 'bash'
  assert_success "$BATS_TEST_BINDIR"
}

# See the implementation comment for an explanation of why this is important.
@test "$SUITE: forwarding script calls exec on the forwarded program" {
  create_bats_test_script 'dollar-and-ppid-should-match' \
    'if [[ "$1" == "print PPID" ]]; then' \
    "  printf '%d\n' \"\$PPID\"" \
    '  exit' \
    'fi' \
    'ppid="$("$0" "print PPID")"' \
    'if [[ "$$" -ne "$ppid" ]]; then' \
    "  printf 'parent \$\$:    %s\n' \"\$\$\" >&2" \
    "  printf 'child  \$PPID: %s\n' \"\$ppid\" >&2" \
    '  exit 1' \
    'fi'
  create_forwarding_script 'bash'
  run "$BATS_TEST_ROOTDIR/dollar-and-ppid-should-match"
  restore_program_in_path 'bash'
  assert_success
}

@test "$SUITE: create multiple forwarding scripts at once" {
  skip_if_system_missing 'cp' 'rm'
  local orig_paths=("$(command -v 'bash' 'cp' 'rm')")

  create_forwarding_scripts 'bash' 'cp' 'rm'
  run command -v 'bash' 'cp' 'rm'
  restore_programs_in_path 'bash' 'cp' 'rm'
  assert_success "$BATS_TEST_BINDIR"/{bash,cp,rm}

  run command -v 'bash' 'cp' 'rm'
  assert_success "${orig_paths[@]}"
}

@test "$SUITE: create multiple forwarding scripts that share the same --path" {
  skip_if_system_missing 'printenv'
  local path='/bin:/usr/bin'

  create_forwarding_scripts --path "$path" 'bash' 'printenv'
  PATH="$BATS_TEST_BINDIR" run 'bash' '-c' 'echo $PATH'
  restore_program_in_path 'bash'
  assert_success "$BATS_TEST_BINDIR:$path"

  PATH="$BATS_TEST_BINDIR" run 'printenv' 'PATH'
  restore_program_in_path 'printenv'
  assert_success "$BATS_TEST_BINDIR:$path"
}

@test "$SUITE: run_test_script creates and runs a script in one step" {
  run_test_script 'one-step' \
    'printf "%s\n" "Hello, World!"'
  assert_success 'Hello, World!'
}

# Note that we use `[[ ... ]] || return 1` because Bash 3.x otherwise won't
# return properly when a `[[ ... ]]` condition fails. The `[ ... ]` construct
# works for all versions of Bash, but since `[[ ... ]]` is a generally safer and
# more versatile construct, this seemed a good opportunity to demonstrate the
# use of `|| return 1`.
#
# Incidentally, it should be easy to inject `|| return 1` automatically via
# `bats-preprocess`.
@test "$SUITE: run_bats_test_suite creates and runs a passing test suite" {
  run_bats_test_suite 'passing' \
    '@test "should pass" {' \
    '  [[ $((2 + 2)) -eq 4 ]] || return 1' \
    '}'
  assert_success '1..1' 'ok 1 should pass'
}

@test "$SUITE: run_bats_test_suite runs a test suite with skips" {
  run_bats_test_suite 'skipping' \
    '@test "should skip" {' \
    '  skip "just because"' \
    '  [[ $((2 + 2)) -eq 5 ]] || return 1' \
    '}'
  assert_success '1..1' 'ok 1 # skip (just because) should skip'
}

@test "$SUITE: run_bats_test_suite runs a test suite with failures" {
  run_bats_test_suite 'failing' \
    '@test "should fail" {' \
    '  [[ $((2 + 2)) -eq 5 ]] || return 1' \
    '}'
  assert_failure '1..1' 'not ok 1 should fail' \
    "# (in test file $BATS_TEST_ROOTDIR/failing, line 3)" \
    "#   \`[[ \$((2 + 2)) -eq 5 ]] || return 1' failed"
}

@test "$SUITE: run_bats_test_suite_in_isolation only forwards bash and rm" {
  skip_if_system_missing cp rm mkdir
  run_bats_test_suite_in_isolation 'skipping' \
    ". '$_GO_ROOTDIR/lib/bats/helpers'" \
    '@test "should skip" {' \
    '  skip_if_system_missing cp rm mkdir' \
    '}'
  assert_success '1..1' \
    'ok 1 # skip (cp, mkdir not installed on the system) should skip'
}

@test "$SUITE: run_bats_test_suite_in_isolation can access forwarding scripts" {
  skip_if_system_missing cp rm mkdir
  create_forwarding_scripts 'cp' 'mkdir'
  run_bats_test_suite_in_isolation 'not-skipping' \
    ". '$_GO_ROOTDIR/lib/bats/helpers'" \
    '@test "should not skip when commands forwarded" {' \
    '  skip_if_system_missing cp rm mkdir' \
    '}'
  restore_programs_in_path 'cp' 'mkdir'
  assert_success '1..1' 'ok 1 should not skip when commands forwarded'
}
