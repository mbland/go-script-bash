#! /usr/bin/env bats

load environment

TEST_SCRIPT="$BATS_TEST_ROOTDIR/do_test.bats"
FAILING_TEST_SCRIPT="$BATS_TEST_ROOTDIR/fail.bash"
export TEST_OUTPUT_FILE="$BATS_TEST_ROOTDIR/test-output.txt"

setup() {
  mkdir "$BATS_TEST_ROOTDIR"
}

teardown() {
  remove_bats_test_dirs
}

expect_success() {
  local command="$1"
  local assertion="$2"
  local __assertion_output
  local __assertion_status

  run_command_then_run_assertion_in_subshell "$command" "$assertion"

  if [[ "$__assertion_status" -ne '0' ]]; then
    printf "In subshell: expected passing status, actual %d\nOutput:\n%s\n" \
      "$__assertion_status" "$__assertion_output" >&2
    return 1
  fi
  check_expected_output "$__assertion_output"

  # Although we expect the assertion under test to pass, this script injects a
  # failing assertion after it to check that the assertion under test calls
  # `return_from_bats_assertion` upon returning. If it doesn't, the failing
  # assertion will show the passing assertion's stack, per issue #48.
  run_test_script \
    "  run $command" \
    "  $assertion" \
    '  assert_equal_numbers() { [[ "$1" -eq "$2" ]]; }' \
    '  assert_equal_numbers 0 1'

  __expected_output=('1..1'
    "not ok 1 $BATS_TEST_DESCRIPTION"
    "# (from function \`assert_equal_numbers' in file $TEST_SCRIPT, line 6,"
    "#  in test file $TEST_SCRIPT, line 7)"
    "#   \`assert_equal_numbers 0 1' failed")
  check_expected_output "$output"
}

expect_failure() {
  local command="$1"
  local assertion="$2"
  shift 2
  local __assertion_output
  local __assertion_status
  local i

  run_command_then_run_assertion_in_subshell "$command" "$assertion"

  if [[ "$__assertion_status" -eq '0' ]]; then
    printf "In subshell: expected failure, but succeeded\nOutput:\n%s\n" \
      "$__assertion_output" >&2
    return 1
  fi

  local __expected_output=("$@")
  check_expected_output "$__assertion_output"

  run_test_script "  run $command" "  $assertion"

  if [[ "$status" -eq '0' ]]; then
    printf "In script: expected failure, but succeeded\nOutput:\n%s\n" \
      "$output" >&2
    return 1
  fi

  __expected_output=('1..1'
    "not ok 1 $BATS_TEST_DESCRIPTION"
    "# (in test file $TEST_SCRIPT, line 5)"
    "#   \`$assertion' failed"
    "${__expected_output[@]/#/# }")
  check_expected_output "$output"
}

# The `command` is executed in-process to set `output`, `status`, and `lines`.
# The `assertion` is executed in a process substitution (subshell) so that its
# __assertion_output and __assertion_status can be captured and evaluated while
# leaving `output`, `status`, and `lines` intact for later checks.
run_command_then_run_assertion_in_subshell() {
  local command="$1"
  local assertion="$2"
  local line

  eval run $command
  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^exit:([0-9]+)$ ]]; then
      __assertion_status="${BASH_REMATCH[1]}"
    else
      __assertion_output+="$line"$'\n'
    fi
  done < <(trap 'echo exit:$?' EXIT; eval $assertion 2>&1; exit "$?")

  # Trim trailing newline to match typical `output` behavior.
  __assertion_output="${__assertion_output%$'\n'}"
}

run_test_script() {
  create_bats_test_script "${TEST_SCRIPT#$BATS_TEST_ROOTDIR}" \
    '#! /usr/bin/env bats' \
    "load '$_GO_CORE_DIR/lib/bats/assertions'" \
    "@test \"$BATS_TEST_DESCRIPTION\" {" \
    "$@" \
    '}'
  run "$TEST_SCRIPT"
}

write_failing_test_script() {
  create_bats_test_script "${FAILING_TEST_SCRIPT#$BATS_TEST_ROOTDIR}" \
    'echo "$@"; exit 1'
}

check_expected_output() {
  local actual_output="$1"
  local IFS=$'\n'

  if [[ "$actual_output" != "${__expected_output[*]}" ]]; then
    printf 'Actual output differs from expected output:\n' >&2
    printf -- '-------\nEXPECTED:\n%s\n-------\nACTUAL:\n%s\n-------\n' \
      "${__expected_output[*]}" "$actual_output" >&2
    return 1
  fi
}

# Since we can't really redirect output as part of an `expect_success` or
# `expect_failure` argument (it redirects the output from `eval run $command`),
# this encapsulates the redirection to `TEST_OUTPUT_FILE`.
#
# This function and `TEST_OUTPUT_FILE` are exported to make them available to
# generated test scripts.
test_file_printf() {
  echo "printf \"$*\" \>\"$TEST_OUTPUT_FILE\""
  printf "$@" >"$TEST_OUTPUT_FILE"
}
export -f test_file_printf

@test "$SUITE: fail prints status and output, returns error" {
  expect_failure "echo 'Hello, world!'" \
    'fail' \
    'STATUS: 0' \
    'OUTPUT:' \
    'Hello, world!'
}

@test "$SUITE: fail handles strings containing percentage signs" {
  expect_failure "echo '% not interpreted as a format spec'" \
    'fail' \
    'STATUS: 0' \
    'OUTPUT:' \
    '% not interpreted as a format spec'
}

@test "$SUITE: fail uses the supplied reason message" {
  expect_failure "echo 'Goodbye, world!'" \
    'fail "You say \"Goodbye,\" while I say \"Hello...\""' \
    'You say "Goodbye," while I say "Hello..."' \
    'STATUS: 0' \
    'OUTPUT:' \
    'Goodbye, world!'
}

@test "$SUITE: assert_equal success" {
  expect_success "echo 'Hello, world!'" \
    'assert_equal "Hello, world!" "$output" "echo result"'
}

@test "$SUITE: assert_equal failure" {
  expect_failure "echo 'Hello, world!'" \
    'assert_equal "Goodbye, world!" "$output" "echo result"' \
    'echo result not equal to expected value:' \
    "  expected: 'Goodbye, world!'" \
    "  actual:   'Hello, world!'"
}

@test "$SUITE: assert_matches success" {
  expect_success "echo 'Hello, world!'" \
    'assert_matches "o, w" "$output" "echo result"'
}

@test "$SUITE: assert_matches failure" {
  expect_failure "echo 'Hello, world!'" \
    'assert_matches "e, w" "$output" "echo result"' \
    'echo result does not match expected pattern:' \
    "  pattern: 'e, w'" \
    "  value:   'Hello, world!'"
}

@test "$SUITE: assert_output success" {
  expect_success "echo 'Hello, world!'" \
    "assert_output 'Hello, world!'"
}

@test "$SUITE: assert_output fail output check" {
  expect_failure "echo 'Hello, world!'" \
    "assert_output 'Goodbye, world!'" \
    'output not equal to expected value:' \
    "  expected: 'Goodbye, world!'" \
    "  actual:   'Hello, world!'"
}

@test "$SUITE: assert_output empty string check" {
  expect_success 'echo' \
    'assert_output ""'
}

@test "$SUITE: assert_output fail empty string check" {
  expect_failure 'echo "Not empty"' \
    "assert_output ''" \
    'output not equal to expected value:' \
    "  expected: ''" \
    "  actual:   'Not empty'"
}

@test "$SUITE: assert_output fails if more than one argument" {
  expect_failure "echo 'Hello, world!'" \
    "assert_output 'Hello,' 'world!'" \
    'ERROR: assert_output takes exactly one argument'
}

@test "$SUITE: assert_output_matches success" {
  expect_success "echo 'Hello, world!'" \
    "assert_output_matches 'o, w'"
}

@test "$SUITE: assert_output_matches failure" {
  expect_failure "echo 'Hello, world!'" \
    "assert_output_matches 'e, w'" \
    'output does not match expected pattern:' \
    "  pattern: 'e, w'" \
    "  value:   'Hello, world!'"
}

@test "$SUITE: assert_status" {
  expect_success "echo 'Hello, world!'" \
    "assert_status '0'"
}

@test "$SUITE: assert_status failure" {
  expect_failure "echo 'Hello, world!'" \
    "assert_status '1'" \
    'exit status not equal to expected value:' \
    "  expected: '1'" \
    "  actual:   '0'"
}

@test "$SUITE: assert_success without output check" {
  expect_success "echo 'Hello, world!'" \
    'assert_success'
}

@test "$SUITE: assert_success failure" {
  write_failing_test_script
  expect_failure "'$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    'assert_success' \
    'expected success, but command failed' \
    'STATUS: 1' \
    'OUTPUT:' \
    'Hello, world!'
}

@test "$SUITE: assert_success with output check" {
  expect_success "echo 'Hello, world!'" \
    "assert_success 'Hello, world!'"
}

@test "$SUITE: assert_success output check failure" {
  expect_failure "echo 'Hello, world!'" \
    "assert_success 'Goodbye, world!'" \
    'output not equal to expected value:' \
    "  expected: 'Goodbye, world!'" \
    "  actual:   'Hello, world!'"
}

@test "$SUITE: assert_failure without output check" {
  write_failing_test_script
  expect_success "'$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    'assert_failure'
}

@test "$SUITE: assert_failure failure" {
  expect_failure "echo 'Hello, world!'" \
    'assert_failure' \
    'expected failure, but command succeeded' \
    'STATUS: 0' \
    'OUTPUT:' \
    'Hello, world!'
}

@test "$SUITE: assert_failure with output check" {
  write_failing_test_script
  expect_success "'$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    "assert_failure 'Hello, world!'"
}

@test "$SUITE: assert_failure output check failure" {
  write_failing_test_script
  expect_failure "'$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    "assert_failure 'Goodbye, world!'" \
    'output not equal to expected value:' \
    "  expected: 'Goodbye, world!'" \
    "  actual:   'Hello, world!'"
}

@test "$SUITE: assert_line_equals" {
  expect_success "echo 'Hello, world!'" \
    "assert_line_equals '0' 'Hello, world!'"
}

@test "$SUITE: assert_line_equals with negative index" {
  expect_success "echo 'Hello, world!'" \
    "assert_line_equals '-1' 'Hello, world!'"
}

@test "$SUITE: assert_line_equals failure" {
  expect_failure "echo 'Hello, world!'" \
    "assert_line_equals '0' 'Goodbye, world!'" \
    'line 0 not equal to expected value:' \
    "  expected: 'Goodbye, world!'" \
    "  actual:   'Hello, world!'" \
    'OUTPUT:' \
    'Hello, world!'
}

@test "$SUITE: assert_line_matches" {
  expect_success "echo 'Hello, world!'" \
    "assert_line_matches '0' 'o, w'"
}

@test "$SUITE: assert_line_matches failure" {
  expect_failure "echo 'Hello, world!'" \
    "assert_line_matches 0 'e, w'" \
    'line 0 does not match expected pattern:' \
    "  pattern: 'e, w'" \
    "  value:   'Hello, world!'" \
    'OUTPUT:' \
    'Hello, world!'
}

@test "$SUITE: assert_line_matches failure handles percent signs in output" {
  expect_failure "echo '% not interpreted as a format spec'" \
    "assert_line_matches 0 '% interpreted as a format spec'" \
    'line 0 does not match expected pattern:' \
    "  pattern: '% interpreted as a format spec'" \
    "  value:   '% not interpreted as a format spec'" \
    'OUTPUT:' \
    '% not interpreted as a format spec'
}

@test "$SUITE: assert_lines_equal" {
  expect_success "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_equal 'foo' 'bar' 'baz'"
}

@test "$SUITE: assert_lines_equal failure" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_equal 'foo' 'quux' 'baz'" \
    'line 1 not equal to expected value:' \
    "  expected: 'quux'" \
    "  actual:   'bar'" \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: assert_lines_equal failure due to one output line too many" {
  expect_failure "printf 'foo\nbar\nbaz\nquux\n'" \
    "assert_lines_equal 'foo' 'bar' 'baz'" \
    'There is one more line of output than expected:' \
    'quux' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz' \
    'quux'
}

@test "$SUITE: assert_lines_equal failure from bad matches and too many lines" {
  expect_failure "printf 'foo\nbar\nbaz\nquux\nxyzzy\nplugh\n'" \
    "assert_lines_equal 'frobozz' 'frotz' 'blorple'" \
    'line 0 not equal to expected value:' \
    "  expected: 'frobozz'" \
    "  actual:   'foo'" \
    'line 1 not equal to expected value:' \
    "  expected: 'frotz'" \
    "  actual:   'bar'" \
    'line 2 not equal to expected value:' \
    "  expected: 'blorple'" \
    "  actual:   'baz'" \
    'There are 3 more lines of output than expected:' \
    'quux' \
    'xyzzy' \
    'plugh' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz' \
    'quux' \
    'xyzzy' \
    'plugh'
}

@test "$SUITE: assert_lines_equal failure due to one output line too few" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_equal 'foo' 'bar' 'baz' 'quux'" \
    'line 3 not equal to expected value:' \
    "  expected: 'quux'" \
    "  actual:   ''" \
    'There is one fewer line of output than expected.' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: assert_lines_equal failure from bad matches and too few lines" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_equal 'frobozz' 'frotz' 'blorple' 'quux' 'xyzzy' 'plugh'" \
    'line 0 not equal to expected value:' \
    "  expected: 'frobozz'" \
    "  actual:   'foo'" \
    'line 1 not equal to expected value:' \
    "  expected: 'frotz'" \
    "  actual:   'bar'" \
    'line 2 not equal to expected value:' \
    "  expected: 'blorple'" \
    "  actual:   'baz'" \
    'line 3 not equal to expected value:' \
    "  expected: 'quux'" \
    "  actual:   ''" \
    'line 4 not equal to expected value:' \
    "  expected: 'xyzzy'" \
    "  actual:   ''" \
    'line 5 not equal to expected value:' \
    "  expected: 'plugh'" \
    "  actual:   ''" \
    'There are 3 fewer lines of output than expected.' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: assert_lines_match" {
  expect_success "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_match 'f.*' 'b[a-z]r' '^baz$'"
}

@test "$SUITE: assert_lines_match failure" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_match 'f.*' 'qu+x' '^baz$'" \
    'line 1 does not match expected pattern:' \
    "  pattern: 'qu+x'" \
    "  value:   'bar'" \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: set_bats_output_and_lines_from_file" {
  assert_equal '' "$output" 'output before'
  assert_equal '' "${lines[*]}" 'lines before'

  test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'
  set_bats_output_and_lines_from_file "$TEST_OUTPUT_FILE"

  # Note that the trailing newline is stripped, which is consistent with how
  # `output` is conventionally set.
  assert_equal $'\nfoo\n\nbar\n\nbaz\n' "$output" 'output after'
  assert_lines_equal '' 'foo' '' 'bar' '' 'baz' ''
}

@test "$SUITE: set_bats_output_and_lines_from_file fails if file is missing" {
  run set_bats_output_and_lines_from_file "$TEST_OUTPUT_FILE"
  assert_failure "'$TEST_OUTPUT_FILE' doesn't exist or isn't a regular file."
}

@test "$SUITE: set_bats_output_and_lines_from_file fails if not regular file" {
  run set_bats_output_and_lines_from_file "${BATS_TEST_ROOTDIR}"
  assert_failure "'$BATS_TEST_ROOTDIR' doesn't exist or isn't a regular file."
}

@test "$SUITE: set_bats_output_and_lines_from_file fails if permission denied" {
  skip_if_cannot_trigger_file_permission_failure

  test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'
  chmod u-r "$TEST_OUTPUT_FILE"
  run set_bats_output_and_lines_from_file "$TEST_OUTPUT_FILE"
  assert_failure "You don't have permission to access '$TEST_OUTPUT_FILE'."
}

@test "$SUITE: assert_file_equals" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_equals '$TEST_OUTPUT_FILE' '' 'foo' '' 'bar' '' 'baz' ''"
}

@test "$SUITE: assert_file_equals failure" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_equals '$TEST_OUTPUT_FILE' '' 'foo' '' 'quux' '' 'baz' ''" \
    'line 3 not equal to expected value:' \
    "  expected: 'quux'" \
    "  actual:   'bar'" \
    'OUTPUT:' \
    '' \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    ''
}

@test "$SUITE: assert_file_matches" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_matches '$TEST_OUTPUT_FILE' 'foo.*b[a-z]r.*baz'"
}

@test "$SUITE: assert_file_matches failure" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_matches '$TEST_OUTPUT_FILE' 'foo.*qu+x.*baz'" \
    "The content of '$TEST_OUTPUT_FILE' does not match expected pattern:" \
    "  pattern: 'foo.*qu+x.*baz'" \
    "  value:   '" \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    "'"
}

@test "$SUITE: assert_file_lines_match" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_lines_match '$TEST_OUTPUT_FILE' \
      '^$' 'f.*' '^$' 'b[a-z]r' '^$' '^baz$' '^$'"
}

@test "$SUITE: assert_file_lines_match failure" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "assert_file_lines_match '$TEST_OUTPUT_FILE' \
      '^$' 'f.*' '^$' 'qu+x' '^$' '^baz$' '^$'" \
    'line 3 does not match expected pattern:' \
    "  pattern: 'qu+x'" \
    "  value:   'bar'" \
    'OUTPUT:' \
    '' \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    ''
}

@test "$SUITE: fail_if fails when assertion unknown" {
  expect_failure "echo 'Hello, world!'" \
    'fail_if foobar "$output" "echo result"' \
    "Unknown assertion: 'assert_foobar'"
}

@test "$SUITE: fail_if succeeds when assert_equal fails" {
  expect_success "echo 'Hello, world!'" \
    'fail_if equal "Goodbye, world!" "$output" "echo result"'
}

@test "$SUITE: fail_if fails when assert_equal succeeds" {
  expect_failure "echo 'Hello, world!'" \
    'fail_if equal "Hello, world!" "$output" "echo result"' \
    'Expected echo result not to equal:' \
    "  'Hello, world!'"
}

@test "$SUITE: fail_if succeeds when assert_matches fails" {
  expect_success "echo 'Hello, world!'" \
    'fail_if matches "Goodbye" "$output" "echo result"'
}

@test "$SUITE: fail_if fails when assert_matches succeeds" {
  expect_failure "echo 'Hello, world!'" \
    'fail_if matches "Hello" "$output" "echo result"' \
    'Expected echo result not to match:' \
    "  'Hello'"
}

@test "$SUITE: fail_if succeeds when assert_output fails" {
  expect_success "echo 'Hello, world!'" \
    "fail_if output 'Goodbye, world!'"
}

@test "$SUITE: fail_if fails when assert_output succeeds" {
  expect_failure "echo 'Hello, world!'" \
    "fail_if output 'Hello, world!'" \
    'Expected output not to equal:' \
    "  'Hello, world!'"
}

@test "$SUITE: fail_if succeeds when assert_output_matches fails" {
  expect_success "echo 'Hello, world!'" \
    "fail_if output_matches 'Goodbye'"
}

@test "$SUITE: fail_if fails when assert_output_matches succeeds" {
  expect_failure "echo 'Hello, world!'" \
    "fail_if output_matches 'Hello'" \
    'Expected output not to match:' \
    "  'Hello'"
}

@test "$SUITE: fail_if succeeds when assert_status fails" {
  expect_success "echo 'Hello, world!'" \
    "fail_if status '1'"
}

@test "$SUITE: fail_if fails when assert_status succeeds" {
  expect_failure "echo 'Hello, world!'" \
    "fail_if status '0'" \
    'Expected status not to equal:' \
    "  '0'"
}

@test "$SUITE: fail_if succeeds when assert_line_equals fails" {
  expect_success "echo 'Hello, world!'" \
    "fail_if line_equals '0' 'Goodbye, world!'"
}

@test "$SUITE: fail_if fails when assert_line_equals succeeds" {
  expect_failure "echo 'Hello, world!'" \
    "fail_if line_equals '0' 'Hello, world!'" \
    'Expected line 0 not to equal:' \
    "  'Hello, world!'"
}

@test "$SUITE: fail_if succeeds when assert_line_matches fails" {
  expect_success "echo 'Hello, world!'" \
    "fail_if line_matches '0' 'Goodbye'"
}

@test "$SUITE: fail_if fails when assert_line_matches succeeds" {
  expect_failure "echo 'Hello, world!'" \
    "fail_if line_matches '0' 'Hello'" \
    'Expected line 0 not to match:' \
    "  'Hello'"
}

@test "$SUITE: fail_if succeeds when assert_lines_match fails" {
  expect_success "printf 'foo\nbar\nbaz\n'" \
    "fail_if lines_match 'f.*' 'qu+x' '^baz\$'"
}

@test "$SUITE: fail_if fails when assert_lines_match succeeds" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "fail_if lines_match 'f.*' 'b[a-z]r' '^baz\$'" \
    'Expected lines not to match:' \
    "  'f.*'" \
    "  'b[a-z]r'" \
    "  '^baz\$'" \
    'STATUS: 0' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: fail_if succeeds when assert_lines_equal fails" {
  expect_success "printf 'foo\nbar\nbaz\n'" \
    "fail_if lines_equal 'foo' 'quux' 'baz'"
}

@test "$SUITE: fail_if fails when assert_lines_equal succeeds" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "fail_if lines_equal 'foo' 'bar' 'baz'" \
    'Expected lines not to equal:' \
    "  'foo'" \
    "  'bar'" \
    "  'baz'" \
    'STATUS: 0' \
    'OUTPUT:' \
    'foo' \
    'bar' \
    'baz'
}

@test "$SUITE: fail_if succeeds when assert_file_equals fails" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_equals '$TEST_OUTPUT_FILE' '' 'foo' '' 'quux' '' 'baz' ''"
}

@test "$SUITE: fail_if fails when assert_file_equals succeeds" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_equals '$TEST_OUTPUT_FILE' '' 'foo' '' 'bar' '' 'baz' ''" \
    "Expected '$TEST_OUTPUT_FILE' not to equal:" \
    "  ''" \
    "  'foo'" \
    "  ''" \
    "  'bar'" \
    "  ''" \
    "  'baz'" \
    "  ''" \
    'STATUS: 0' \
    'OUTPUT:' \
    '' \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    ''
}

@test "$SUITE: fail_if succeeds when assert_file_matches fails" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_matches '$TEST_OUTPUT_FILE' 'foo.*qu+x.*baz'"
}

@test "$SUITE: fail_if fails when assert_file_matches succeeds" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_matches '$TEST_OUTPUT_FILE' 'foo.*b[a-z]r.*baz'" \
    "Expected '$TEST_OUTPUT_FILE' not to match:" \
    "  'foo.*b[a-z]r.*baz'" \
    'STATUS: 0' \
    'OUTPUT:' \
    '' \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    ''
}

@test "$SUITE: fail_if succeeds when assert_file_lines_match fails" {
  expect_success "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_lines_match '$TEST_OUTPUT_FILE' \
      '^$' 'f.*' '^$' 'qu+x' '^$' '^baz$' '^$'"
}

@test "$SUITE: fail_if fails when assert_file_lines_match succeeds" {
  expect_failure "test_file_printf '\nfoo\n\nbar\n\nbaz\n\n'" \
    "fail_if file_lines_match '$TEST_OUTPUT_FILE' \
      '^$' 'f.*' '^$' 'b[a-z]r' '^$' '^baz$' '^$'" \
    "Expected '$TEST_OUTPUT_FILE' not to match:" \
    "  '^$'" \
    "  'f.*'" \
    "  '^$'" \
    "  'b[a-z]r'" \
    "  '^$'" \
    "  '^baz$'" \
    "  '^$'" \
    'STATUS: 0' \
    'OUTPUT:' \
    '' \
    'foo' \
    '' \
    'bar' \
    '' \
    'baz' \
    ''
}
