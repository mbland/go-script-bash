#! /usr/bin/env bats

load environment
load assertions

TEST_SCRIPT="$BATS_TMPDIR/do_test.bats"
FAILING_TEST_SCRIPT="$BATS_TMPDIR/fail.bash"

setup() {
  cp "$BATS_TEST_DIRNAME/assertions.bash" "$BATS_TMPDIR"
}

teardown() {
  rm -f "$TEST_SCRIPT" "$BATS_TMPDIR/assertions.bash" "$FAILING_TEST_SCRIPT"
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

check_passing_status() {
  if [[ "$status" -ne 0 ]]; then
    printf "Expected passing status, actual %d\nOutput:\n%s\n" \
      "$status" "$output"
    return 1
  fi

  local __expected_output=('1..1' "ok 1 $BATS_TEST_DESCRIPTION")
  check_expected_output
}

check_failing_status_and_output() {
  local expected_status="$1"
  local assertion="$2"
  shift
  shift

  if [[ "$status" -ne "$expected_status" ]]; then
    printf "Expected status %d, actual %d\nOutput:\n%s\n" \
      "$expected_status" "$status" "$output"
    return 1
  fi

  local __expected_output=('1..1'
    "not ok 1 $BATS_TEST_DESCRIPTION"
    "# (in test file $TEST_SCRIPT, line 5)"
    "#   \`$assertion' failed"
    "$@")
  check_expected_output
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
  run_test_script "run echo 'Hello, world!'" \
    'fail'
  check_failing_status_and_output 1 'fail' \
    '# STATUS: 0' \
    '# OUTPUT:' \
    '# Hello, world!'
}

@test "$SUITE: assert_equal success" {
  run_test_script "run echo 'Hello, world!'" \
    'assert_equal "Hello, world!" "$output" "echo result"'
  check_passing_status
}

@test "$SUITE: assert_equal failure" {
  local assertion='assert_equal "Goodbye, world!" "$output" "echo result"'
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# echo result not equal to expected value:' \
    "#   expected: 'Goodbye, world!'" \
    "#   actual:   'Hello, world!'"
}

@test "$SUITE: assert_matches success" {
  run_test_script "run echo 'Hello, world!'" \
    'assert_matches "o, w" "$output" "echo result"'
  check_passing_status
}

@test "$SUITE: assert_matches failure" {
  local assertion='assert_matches "e, w" "$output" "echo result"'
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# echo result does not match expected pattern:' \
    "#   pattern: 'e, w'" \
    "#   value:   'Hello, world!'"
}

@test "$SUITE: assert_output success if null expected value" {
  run_test_script 'run :' \
    'assert_output'
  check_passing_status
}

@test "$SUITE: assert_output success" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_output 'Hello, world!'"
  check_passing_status
}

@test "$SUITE: assert_output fail output check" {
  local assertion="assert_output 'Goodbye, world!'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# output not equal to expected value:' \
    "#   expected: 'Goodbye, world!'" \
    "#   actual:   'Hello, world!'"
}

@test "$SUITE: assert_output empty string check" {
  run_test_script 'run echo' \
    'assert_output ""'
  check_passing_status
}

@test "$SUITE: assert_output fail empty string check" {
  local assertion="assert_output ''"
  run_test_script 'run echo "Not empty"' \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# output not equal to expected value:' \
    "#   expected: ''" \
    "#   actual:   'Not empty'"
}

@test "$SUITE: assert_output fails if more than one argument" {
  local assertion="assert_output 'Hello,' 'world!'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# ERROR: assert_output takes only one argument'
}

@test "$SUITE: assert_output_matches success" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_output_matches 'o, w'"
  check_passing_status
}

@test "$SUITE: assert_output_matches failure" {
  local assertion="assert_output_matches 'e, w'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# output does not match expected pattern:' \
    "#   pattern: 'e, w'" \
    "#   value:   'Hello, world!'"
}

@test "$SUITE: assert_status" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_status '0'"
  check_passing_status
}

@test "$SUITE: assert_status failure" {
  local assertion="assert_status '1'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# exit status not equal to expected value:' \
    "#   expected: '1'" \
    "#   actual:   '0'"
}

@test "$SUITE: assert_success without output check" {
  run_test_script "run echo 'Hello, world!'" \
    'assert_success'
  check_passing_status
}

@test "$SUITE: assert_success failure" {
  local assertion='assert_success'
  write_failing_test_script
  run_test_script "run '$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# expected success, but command failed' \
    '# STATUS: 1' \
    '# OUTPUT:' \
    '# Hello, world!'
}

@test "$SUITE: assert_success with output check" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_success 'Hello, world!'"
  check_passing_status
}

@test "$SUITE: assert_success output check failure" {
  local assertion="assert_success 'Goodbye, world!'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# output not equal to expected value:' \
    "#   expected: 'Goodbye, world!'" \
    "#   actual:   'Hello, world!'"
}

@test "$SUITE: assert_failure without output check" {
  write_failing_test_script
  run_test_script "run '$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    'assert_failure'
  check_passing_status
}

@test "$SUITE: assert_failure failure" {
  local assertion='assert_failure'
  run_test_script "run echo 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# expected failure, but command succeeded' \
    '# STATUS: 0' \
    '# OUTPUT:' \
    '# Hello, world!'
}

@test "$SUITE: assert_failure with output check" {
  write_failing_test_script
  run_test_script "run '$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    "assert_failure 'Hello, world!'"
  check_passing_status
}

@test "$SUITE: assert_failure output check failure" {
  local assertion="assert_failure 'Goodbye, world!'"
  write_failing_test_script
  run_test_script "run '$FAILING_TEST_SCRIPT' 'Hello, world!'" \
    "$assertion"
  check_failing_status_and_output 1 "$assertion" \
    '# output not equal to expected value:' \
    "#   expected: 'Goodbye, world!'" \
    "#   actual:   'Hello, world!'"
}

@test "$SUITE: assert_line_equals" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_line_equals 0 'Hello, world!'"
  check_passing_status
}

@test "$SUITE: assert_line_equals with negative index" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_line_equals -1 'Hello, world!'"
  check_passing_status
}

@test "$SUITE: assert_line_equals failure" {
  local assertion="assert_line_equals 0 'Goodbye, world!'"
  run_test_script "run echo 'Hello, world!'" \
  check_failing_status_and_output 1 "$assertion" \
    '# line 0 not equal to expected value:' \
    "#   expected: 'Goodbye, world!'" \
    "#   actual:   'Hello, world!'" \
    '# OUTPUT:' \
    '# Hello, world!'
}

@test "$SUITE: assert_line_matches" {
  run_test_script "run echo 'Hello, world!'" \
    "assert_line_matches 0 'o, w'"
  check_passing_status
}

@test "$SUITE: assert_line_matches failure" {
  local assertion="assert_line_matches 0 'e, w'"
  run_test_script "run echo 'Hello, world!'" \
    "$assertion" \
  check_failing_status_and_output 1 "$assertion" \
    '# line 0 does not match expected pattern:' \
    "#   pattern: 'e, w'" \
    "#   value:   'Hello, world!'" \
    '# OUTPUT:' \
    '# Hello, world!'
}
