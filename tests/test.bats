#! /usr/bin/env bats
#
# Tests for scripts/test.

load environment
load assertions
load script_helper

teardown() {
  restore_stubbed_core_modules
  remove_test_go_rootdir
}

@test "$SUITE: tab complete flags" {
  run ./go test --complete 0 '-'
  local expected=('--coverage' '--edit' '--list')
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: tab complete flags, first-level tests and directories" {
  local expected=('--coverage' '--edit' '--list')
  expected+=($('./go' 'glob' '--complete' '5' \
    '--trim' '--ignore' 'bats' 'tests' '.bats'))
  [[ "${#expected[@]}" -ne 1 ]]

  run ./go test --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: tab completion matches test file and matching directory" {
  expected=('core' 'core/')
  run ./go test --complete 0 'core'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

_trim_expected() {
  expected=("${expected[@]#tests/}")
  expected=("${expected[@]%.bats}")
}

@test "$SUITE: tab completion lists second-level tests and directories" {
  local expected=(tests/core/*.bats)
  _trim_expected

  run ./go test --complete 0 'core/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: no arguments after --list lists all tests" {
  local expected=(
    $('./go' 'glob' '--trim' '--ignore' 'bats' 'tests' '.bats'))
  [[ "${#expected[@]}" -ne 0 ]]

  run ./go test --list
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list specific files and directories" {
  run ./go test --list test aliases 'builtins*'

  local expected=(test aliases builtins tests/builtins/*)
  _trim_expected

  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: open EDITOR on --edit" {
  run env EDITOR='echo' ./go test --edit test aliases 'builtins*'
  local expected=(
    'tests/test.bats' 'tests/aliases.bats' 'tests/builtins.bats'
    tests/builtins/*)
  assert_success "${expected[*]}"
}

@test "$SUITE: produce an error if any test pattern fails to match" {
  run ./go test --list test 'foo*'
  assert_failure '"foo*" does not match any .bats files in tests.'
}

@test "$SUITE: update bats submodule if not present" {
  mkdir -p "$TEST_GO_SCRIPTS_DIR/bin"

  local git_dummy="$TEST_GO_SCRIPTS_DIR/bin/git"
  printf '#! /usr/bin/env bash\necho "GIT ARGV: $*"\n' >"$git_dummy"
  chmod 700 "$git_dummy"

  cp "$_GO_ROOTDIR/scripts/test" "$TEST_GO_SCRIPTS_DIR"
  create_test_go_script "PATH=\"$TEST_GO_SCRIPTS_DIR/bin:\$PATH\"; @go \"\$@\""

  # This will fail because we didn't create the tests/ directory, but git should
  # have been called correctly.
  run "$TEST_GO_SCRIPT" test --list test
  local expected_output=(
    'GIT ARGV: submodule update --init tests/bats'
    'Root directory argument tests is not a directory.')
  local IFS=$'\n'
  assert_failure "${expected_output[*]}"
}

write_bats_dummy_stub_kcov_lib_and_copy_test_script() {
  # Avoid `git submodule update` by writing dummy bats.
  create_bats_test_script "tests/bats/libexec/bats"

  # Stub the kcov lib to assert it's called correctly.
  create_core_module_stub 'kcov-ubuntu' \
    "run_kcov() { IFS=\$'\n'; echo \"\$*\"; }"

  if [[ ! -d "$TEST_GO_SCRIPTS_DIR" ]]; then
    mkdir "$TEST_GO_SCRIPTS_DIR"
  fi
  cp "$_GO_ROOTDIR/scripts/test" "$TEST_GO_SCRIPTS_DIR"
}

@test "$SUITE: coverage run" {
  write_bats_dummy_stub_kcov_lib_and_copy_test_script
  create_test_go_script '@go "$@"'

  local test_cmd_argv=("$TEST_GO_SCRIPT" 'test' '--coverage' 'foo' 'bar/baz')
  local expected_kcov_args=(
    'tests/kcov'
    'tests/coverage'
    'go,go-core.bash,lib/,libexec/,scripts/'
    '/tmp,tests/bats/'
    'https://coveralls.io/github/mbland/go-script-bash'
    "$TEST_GO_SCRIPT"
    'test'
    'foo'
    'bar/baz')

  run env _COVERAGE_RUN= TRAVIS_OS_NAME= "${test_cmd_argv[@]}"
  local IFS=$'\n'
  assert_success "${expected_kcov_args[*]}"
}

# This test also makes sure the invocation doesn't cause a second recursive call
# to `run_kcov` thanks to the `_COVERAGE_RUN` variable.  Previously, seemingly
# successful coverage runs (added in commit
# 4440832c257c3fa455d7d773ee56fd66c4431a19) were causing Travis failures,
# ameliorated in commit cc284d11e010442392029afdcddc5b1c761ad9a0. These were
# due to the `run_kcov` getting called recursively and failing because the first
# call already created the `tests/coverage` directory.
#
# Here was the chain of events:
#
# - Travis calls `./go test`.
# - Test suite runs and succeeds.
# - `"$?" -eq '0' && "$TRAVIS_OS_NAME" == 'linux'` condition met.
# - `_test_coverage` and `run_kcov` executed.
# - `run_kcov` creates `tests/coverage` and executes `kcov ./go test`.
#   - Test suite runs and succeeds.
#   - `"$?" -eq '0' && "$TRAVIS_OS_NAME" == 'linux'` condition met.
#   - `_test_coverage` and `run_kcov` executed.
#   - `run_kcov` fails because `tests/coverage` already exists.
# - `kcov` sends coverage info to Coveralls, but exits with an error.
# - Travis build reports failure.
#
# With the `_COVERAGE_RUN` variable, the recursive call is now
# short-circuited.
@test "$SUITE: run coverage by default on Travis Linux" {
  write_bats_dummy_stub_kcov_lib_and_copy_test_script
  create_test_go_script '@go "$@"'

  run env _COVERAGE_RUN= TRAVIS_OS_NAME='linux' "$TEST_GO_SCRIPT" test
  assert_success
  assert_line_equals 0 'tests/kcov'
}
