#! /usr/bin/env bats

load assertions

echo_fail() {
  echo "$@"
  return 1
}

@test "assertions: fail prints status and output, returns error" {
  run echo 'Hello, world!'
  run fail
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'STATUS: 0' ]]
  [[ "${lines[1]}" = 'OUTPUT:' ]]
  [[ "${lines[2]}" = 'Hello, world!' ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_equal success" {
  run echo 'Hello, world!'
  run assert_equal 'Hello, world!' "$output" "echo result"
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_equal failure" {
  run echo 'Hello, world!'
  run assert_equal 'Goodbye, world!' "$output" "echo result"
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'echo result not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: 'Goodbye, world!'" ]]
  [[ "${lines[2]}" = "  actual:   'Hello, world!'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_output success if null expected value" {
  run echo 'Hello, world!'
  run assert_output
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_output success" {
  run echo 'Hello, world!'
  run assert_output 'Hello, world!'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_output fail output check" {
  run echo 'Hello, world!'
  run assert_output 'Goodbye, world!'
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'output not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: 'Goodbye, world!'" ]]
  [[ "${lines[2]}" = "  actual:   'Hello, world!'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_output empty string check" {
  run echo
  run assert_output ''
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_output fail empty string check" {
  run echo 'Not empty'
  run assert_output ''
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'output not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: ''" ]]
  [[ "${lines[2]}" = "  actual:   'Not empty'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_output fails if more than one argument" {
  run echo 'Hello, world!'
  run assert_output 'Hello,' 'world!'
  [[ "$status" -eq '1' ]]
  [[ "$output" = 'ERROR: assert_output takes only one argument' ]]
}

@test "assertions: assert_status" {
  run echo 'Hello, world!'
  run assert_status '0'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_status failure" {
  run echo 'Hello, world!'
  run assert_status '1'
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'exit status not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: '1'" ]]
  [[ "${lines[2]}" = "  actual:   '0'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_success without output check" {
  run echo 'Hello, world!'
  run assert_success
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_success failure" {
  run echo_fail 'Hello, world!'
  run assert_success
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'expected success, but command failed' ]]
  [[ "${lines[1]}" = 'STATUS: 1' ]]
  [[ "${lines[2]}" = 'OUTPUT:' ]]
  [[ "${lines[3]}" = 'Hello, world!' ]]
  [[ -z "${lines[4]}" ]]
}

@test "assertions: assert_success with output check" {
  run echo 'Hello, world!'
  run assert_success 'Hello, world!'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_success output check failure" {
  run echo 'Hello, world!'
  run assert_success 'Goodbye, world!'
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'output not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: 'Goodbye, world!'" ]]
  [[ "${lines[2]}" = "  actual:   'Hello, world!'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_failure without output check" {
  run echo_fail 'Hello, world!'
  run assert_failure
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_failure failure" {
  run echo 'Hello, world!'
  run assert_failure
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'expected failure, but command succeeded' ]]
  [[ "${lines[1]}" = 'STATUS: 0' ]]
  [[ "${lines[2]}" = 'OUTPUT:' ]]
  [[ "${lines[3]}" = 'Hello, world!' ]]
  [[ -z "${lines[4]}" ]]
}

@test "assertions: assert_failure with output check" {
  run echo_fail 'Hello, world!'
  run assert_failure 'Hello, world!'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_failure output check failure" {
  run echo_fail 'Hello, world!'
  run assert_failure 'Goodbye, world!'
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'output not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: 'Goodbye, world!'" ]]
  [[ "${lines[2]}" = "  actual:   'Hello, world!'" ]]
  [[ -z "${lines[3]}" ]]
}

@test "assertions: assert_line_equals" {
  run echo 'Hello, world!'
  run assert_line_equals 0 'Hello, world!'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_line_equals with negative index" {
  run echo 'Hello, world!'
  run assert_line_equals -1 'Hello, world!'
  [[ "$status" -eq '0' ]]
  [[ -z "$output" ]]
}

@test "assertions: assert_line_equals failure" {
  run echo 'Hello, world!'
  run assert_line_equals 0 'Goodbye, world!'
  [[ "$status" -eq '1' ]]
  [[ "${lines[0]}" = 'line 0 not equal to expected value:' ]]
  [[ "${lines[1]}" = "  expected: 'Goodbye, world!'" ]]
  [[ "${lines[2]}" = "  actual:   'Hello, world!'" ]]
  [[ "${lines[3]}" = 'OUTPUT:' ]]
  [[ "${lines[4]}" = 'Hello, world!' ]]
  [[ -z "${lines[5]}" ]]
}
