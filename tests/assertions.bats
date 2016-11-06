#! /usr/bin/env bats

load environment

TEST_SCRIPT="$BATS_TMPDIR/do_test.bats"
FAILING_TEST_SCRIPT="$BATS_TMPDIR/fail.bash"

setup() {
  cp "$BATS_TEST_DIRNAME/assertions.bash" "$BATS_TMPDIR"
}

teardown() {
  rm -f "$TEST_SCRIPT" "$BATS_TMPDIR/assertions.bash" "$FAILING_TEST_SCRIPT"
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
  shift
  shift

  eval run $command
  eval run $assertion

  if [[ "$status" -eq '0' ]]; then
    printf "In process: expected failure, but succeeded\nOutput:\n%s\n" \
      "$output" >&2
    return 1
  fi

  local __expected_output=("$@")
  check_expected_output

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
    "load assertions"
    "@test \"$BATS_TEST_DESCRIPTION\" {"
    "$@"
    '}')

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

@test "$SUITE: assert_output success if null expected value" {
  expect_success ':' \
    'assert_output'
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
    'ERROR: assert_output takes only one argument'
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
