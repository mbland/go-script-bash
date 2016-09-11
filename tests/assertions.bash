#! /bin/bash
#
# Assertions for Bats tests
#
# Felt the need for this after several Travis breakages without helpful output,
# then stole some inspiration from rbenv/test/test_helper.bash.

# Any assertion calls this function directly must call `set +o functrace` first.
__return_from_bats_assertion() {
  set +o errexit
  local result="${1:-0}"
  local i

  for ((i=0; i != ${#BATS_CURRENT_STACK_TRACE[0]}; ++i)) do
    if [[ "${BATS_CURRENT_STACK_TRACE[$i]}" =~ $BASH_SOURCE ]]; then
      unset "BATS_CURRENT_STACK_TRACE[$i]"
    else
      break
    fi
  done

  for ((i=0; i != ${#BATS_PREVIOUS_STACK_TRACE[0]}; ++i)) do
    if [[ "${BATS_PREVIOUS_STACK_TRACE[$i]}" =~ $BASH_SOURCE ]]; then
      unset "BATS_PREVIOUS_STACK_TRACE[$i]"
    else
      break
    fi
  done

  set -o errexit
  set -o functrace
  return "$result"
}

fail() {
  set +o functrace
  printf "STATUS: ${status}\nOUTPUT:\n${output}\n" >&2
  __return_from_bats_assertion 1
}

assert_equal() {
  set +o functrace
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$expected" != "$actual" ]]; then
    printf "%s not equal to expected value:\n  %s\n  %s\n" \
      "$label" "expected: '$expected'" "actual:   '$actual'" >&2
    __return_from_bats_assertion 1
  fi
  __return_from_bats_assertion
}

assert_matches() {
  set +o functrace
  local pattern="$1"
  local value="$2"
  local label="$3"

  if [[ ! "$value" =~ $pattern ]]; then
    printf "%s does not match expected pattern:\n  %s\n  %s\n" \
      "$label" "pattern: '$pattern'" "value:   '$value'" >&2
    __return_from_bats_assertion 1
  fi
  __return_from_bats_assertion
}

__assert_output() {
  set +o functrace
  local assertion="$1"
  shift

  unset 'BATS_CURRENT_STACK_TRACE[0]'
  if [[ "$#" -eq '0' ]]; then
    __return_from_bats_assertion
  elif [[ "$#" -ne 1 ]]; then
    echo "ERROR: ${FUNCNAME[1]} takes only one argument" >&2
    __return_from_bats_assertion 1
  fi
  "$assertion" "$1" "$output" 'output'
}

assert_output() {
  __assert_output 'assert_equal' "$@"
}

assert_output_matches() {
  __assert_output 'assert_matches' "$@"
}

assert_status() {
  assert_equal "$1" "$status" "exit status"
}

assert_success() {
  if [[ "$status" -ne '0' ]]; then
    printf 'expected success, but command failed\n' >&2
    fail
  elif [[ "$#" -ne 0 ]]; then
    assert_output "$@"
  fi
}

assert_failure() {
  if [[ "$status" -eq '0' ]]; then
    printf 'expected failure, but command succeeded\n' >&2
    fail
  elif [[ "$#" -ne 0 ]]; then
    assert_output "$@"
  fi
}

__assert_line() {
  set +o functrace
  local assertion="$1"
  local lineno="$2"
  local constraint="$3"

  # Implement negative indices for Bash 3.x.
  if [[ "${lineno:0:1}" == '-' ]]; then
    lineno="$((${#lines[@]} - ${lineno:1}))"
  fi

  if ! "$assertion" "$constraint" "${lines[$lineno]}" "line $lineno"; then
    printf "OUTPUT:\n$output\n" >&2
    __return_from_bats_assertion 1
  fi
  __return_from_bats_assertion
}

assert_line_equals() {
  __assert_line 'assert_equal' "$@"
}

assert_line_matches() {
  __assert_line 'assert_matches' "$@"
}
