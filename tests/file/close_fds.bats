#! /usr/bin/env bats

load ../environment

teardown() {
  remove_test_go_rootdir
}

create_close_fds_test_script() {
  create_test_go_script \
    '. "$_GO_USE_MODULES" "file"' \
    'declare fds=()' \
    'declare fd' \
    "$@" \
    '@go.close_fds "${fds[@]}"' \
    'declare result="$?"' \
    '' \
    'for fd in "${fds[@]}"; do' \
    '  if [[ -e "/dev/fd/$fd" ]]; then' \
    '    echo "/dev/fd/$fd" >&2' \
    '    result=1' \
    '  fi' \
    'done' \
    'exit "$result"'
}

@test "$SUITE: error if no file descriptor arguments" {
  create_close_fds_test_script
  run "$TEST_GO_SCRIPT"

  local expected=("No file descriptors to close specified at:"
    "  $TEST_GO_SCRIPT:6 main")
  local IFS=$'\n'
  assert_failure "${expected[*]}"
}

@test "$SUITE: successfully close stdin, stdout, and stderr" {
  create_close_fds_test_script \
    'fds+=(0 1 2)'
  run "$TEST_GO_SCRIPT"
  assert_success ''
}

@test "$SUITE: error if an argument isn't a file descriptor" {
  create_close_fds_test_script \
    'fds+=(-1)'
  run "$TEST_GO_SCRIPT"

  assert_failure
  assert_line_matches -2 \
    "Failed to close one or more file descriptors: -1 at:"
  assert_line_matches -1 \
    "  $TEST_GO_SCRIPT:7 main"
}
