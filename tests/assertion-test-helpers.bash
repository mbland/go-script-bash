#! /usr/bin/env bash
#
# Assertion functions used by `tests/assertion-test-helpers.bats`

. "$_GO_CORE_DIR/lib/bats/assertions"

__test_assertion_impl() {
  local assertion_status="${ASSERTION_STATUS:-0}"

  if [[ "$assertion_status" -ne '0' || -n "$ASSERTION_FORCE_OUTPUT" ]]; then
    printf '%s%s' "$*" "${ASSERTION_EXTRA_OUTPUT}" >&"${ASSERTION_FD:-2}"

    if [[ -z "$ASSERTION_WITHHOLD_NEWLINE" ]]; then
      printf '\n' >&"${ASSERTION_FD:-2}"
    fi
  fi

  if [[ -n "$DELEGATE_RETURN_FROM_BATS_ASSERTION" ]]; then
    return_from_bats_assertion "$assertion_status"
  else
    return "$assertion_status"
  fi
}

test_assertion() {
  # If an assertion fails to call `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"`,
  # then when it fails, the stack trace will show the implementation details of
  # the assertion, rather than just the line at which it was called.
  set "${TEST_ASSERTION_SHELL_OPTIONS:-$BATS_ASSERTION_DISABLE_SHELL_OPTIONS}"

  __test_assertion_impl "$@"
  local result="$?"

  # If an assertion calls `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"`, but not
  # `return_from_bats_assertion`, it will fail to scrub the stack and restore
  # `set -eET`.
  if [[ -z "$SKIP_RETURN_FROM_BATS_ASSERTION" &&
        -z "$DELEGATE_RETURN_FROM_BATS_ASSERTION" ]]; then
    return_from_bats_assertion "$result"
  else
    return "$result"
  fi
}
