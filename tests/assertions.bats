#! /usr/bin/env bats

load environment

TEST_SCRIPT="$BATS_TEST_ROOTDIR/do_test.bats"
FAILING_TEST_SCRIPT="$BATS_TEST_ROOTDIR/fail.bash"

teardown() {
  rm -f "$TEST_SCRIPT" "$FAILING_TEST_SCRIPT"
}

expect_success() {
  local command="$1"
  local assertion="$2"

  eval run $command
  eval run $assertion

  if [[ "$status" -ne 0 ]]; then
    printf "In process: expected passing status, actual %d\nOutput:\n%s\n" \
      "$status" "$output" >&2
    return 1
  fi

  eval $assertion || :

  if [[ ! "$-" =~ T ]]; then
    printf "The assertion did not reset \`set -o functrace\`: $-" >&2
    return 1
  fi

  run_test_script "  run $command" "  $assertion"

  if [[ "$status" -ne 0 ]]; then
    printf "In script: expected passing status, actual %d\nOutput:\n%s\n" \
      "$status" "$output" >&2
    return 1
  fi

  local __expected_output=('1..1' "ok 1 $BATS_TEST_DESCRIPTION")
  check_expected_output
}

expect_failure() {
  local command="$1"
  local assertion="$2"
  shift 2

  eval run $command
  eval run $assertion

  if [[ "$status" -eq '0' ]]; then
    printf "In process: expected failure, but succeeded\nOutput:\n%s\n" \
      "$output" >&2
    return 1
  fi

  local __expected_output=("$@")
  check_expected_output

  eval $assertion &>/dev/null || :

  if [[ ! "$-" =~ T ]]; then
    printf "The assertion did not reset \`set -o functrace\`: $-" >&2
    return 1
  fi

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
  check_expected_output
}

run_test_script() {
  local lines=('#! /usr/bin/env bats'
    "load '$_GO_CORE_DIR/lib/bats/assertions'"
    "@test \"$BATS_TEST_DESCRIPTION\" {"
    "$@"
    '}')

  mkdir -p "${TEST_SCRIPT%/*}"
  local IFS=$'\n'
  echo "${lines[*]}" > "$TEST_SCRIPT"
  chmod 700 "$TEST_SCRIPT"
  run "$TEST_SCRIPT"
}

write_failing_test_script() {
  echo '#! /usr/bin/env bash' >"$FAILING_TEST_SCRIPT"
  echo 'echo "$@"; exit 1' >>"$FAILING_TEST_SCRIPT"
  chmod 700 "$FAILING_TEST_SCRIPT"
}

check_expected_output() {
  local IFS=$'\n'

  if [[ "$output" != "${__expected_output[*]}" ]]; then
    printf 'EXPECTED:\n%s\n-------\nACTUAL:\n%s\n' \
      "${__expected_output[*]}" "$output" >&2
    return 1
  fi
}

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
    "  actual:   'bar'"
}

@test "$SUITE: assert_lines_equal failure due to one output line too many" {
  expect_failure "printf 'foo\nbar\nbaz\nquux\n'" \
    "assert_lines_equal 'foo' 'bar' 'baz'" \
    'There is one more line of output than expected:' \
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
    'plugh'
}

@test "$SUITE: assert_lines_equal failure due to one output line too few" {
  expect_failure "printf 'foo\nbar\nbaz\n'" \
    "assert_lines_equal 'foo' 'bar' 'baz' 'quux'" \
    'line 3 not equal to expected value:' \
    "  expected: 'quux'" \
    "  actual:   ''" \
    'There is one fewer line of output than expected.'
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
    'There are 3 fewer lines of output than expected.'
}
