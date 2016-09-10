#! /bin/bash
#
# Assertions for Bats tests
#
# Felt the need for this after several Travis breakages without helpful output,
# then stole some inspiration from rbenv/test/test_helper.bash.

fail() {
  printf "STATUS: ${status}\nOUTPUT:\n${output}\n" >&2
  return 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$expected" != "$actual" ]]; then
    printf "%s not equal to expected value:\n  %s\n  %s\n" \
      "$label" "expected: '$expected'" "actual:   '$actual'" >&2
    return 1
  fi
}

assert_matches() {
  local pattern="$1"
  local value="$2"
  local label="$3"

  if [[ ! "$value" =~ $pattern ]]; then
    printf "%s does not match expected pattern:\n  %s\n  %s\n" \
      "$label" "pattern: '$pattern'" "value:   '$value'" >&2
    return 1
  fi
}

__evaluate_output() {
  local assertion="$1"
  shift

  if [[ "$#" -eq '0' ]]; then
    return
  elif [[ "$#" -ne 1 ]]; then
    echo "ERROR: ${FUNCNAME[1]} takes only one argument" >&2
    return 1
  fi
  "$assertion" "$1" "$output" 'output'
  local result="$?"
  return "$result"
}

assert_output() {
  set +o functrace
  __evaluate_output 'assert_equal' "$@"
  local result="$?"
  set -o functrace
  return "$result"
}

assert_output_matches() {
  set +o functrace
  __evaluate_output 'assert_matches' "$@"
  local result="$?"
  set -o functrace
  return "$result"
}

assert_status() {
  set +o functrace
  assert_equal "$1" "$status" "exit status"
  local result="$?"
  set -o functrace
  return "$result"
}

assert_success() {
  if [[ "$status" -ne '0' ]]; then
    printf 'expected success, but command failed\n' >&2
    set +o functrace
    fail
    set -o functrace
    return 1
  fi
  set +o functrace
  assert_output "$@"
  local result="$?"
  set -o functrace
  return "$result"
}

assert_failure() {
  if [[ "$status" -eq '0' ]]; then
    printf 'expected failure, but command succeeded\n' >&2
    set +o functrace
    fail
    set -o functrace
    return 1
  fi
  set +o functrace
  assert_output "$@"
  local result="$?"
  set -o functrace
  return "$result"
}

__evaluate_line() {
  local assertion="$1"
  local lineno="$2"
  local constraint="$3"

  # Implement negative indices for Bash 3.x.
  if [[ "${lineno:0:1}" == '-' ]]; then
    lineno="$((${#lines[@]} - ${lineno:1}))"
  fi

  set +o functrace
  "$assertion" "$constraint" "${lines[$lineno]}" "line $lineno"
  local result="$?"
  set -o functrace

  if [[ "$result" -ne '0' ]]; then
    printf "OUTPUT:\n$output\n" >&2
  fi
  return "$result"
}

assert_line_equals() {
  set +o functrace
  __evaluate_line 'assert_equal' "$@" 
  local result="$?"
  set -o functrace
  return "$result"
}

assert_line_matches() {
  set +o functrace
  __evaluate_line 'assert_matches' "$@" 
  local result="$?"
  set -o functrace
  return "$result"
}
