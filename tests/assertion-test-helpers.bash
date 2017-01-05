#! /usr/bin/env bash
#
# Assertion functions used by `tests/assertion-test-helpers.bats`

. "$_GO_CORE_DIR/lib/bats/assertions"

__test_assertion_impl() {
  local assertion_status="${ASSERTION_STATUS:-0}"

  if [[ "$assertion_status" -ne '0' ]]; then
    printf '%s\n' "$*" >&"${ASSERTION_FD:-2}"
  fi
  return "$assertion_status"
}

test_assertion() {
  local result

  # If an assertion fails to call `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"`,
  # then when it fails, the stack trace will show the implementation details of
  # the assertion, rather than just the line at which it was called.
  if [[ -z "$SKIP_SET_BATS_ASSERTION_DISABLE_SHELL_OPTIONS" ]]; then
    set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"
  fi

  __test_assertion_impl "$@"
  result="$?"

  # If an assertion calls `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"`, but not
  # `return_from_bats_assertion`, it will fail to scrub the stack and restore
  # `set -eET`.
  if [[ -z "$SKIP_RETURN_FROM_BATS_ASSERTION" ]]; then
    return_from_bats_assertion "$result"
  fi
}
