#! /usr/bin/env bats

load environment
load "$_GO_CORE_DIR/lib/bats/background-process"

# We define array variables on one line and assign to it on another thanks to
# Bash <4.25; see commit b421c7382fc1dafb4d865d2357276168eac30744 and
# commit c6bf1cf46c7816c969a0c5d45a4badeb50963f95.
SKIP_TEST=
BACKGROUND_SCRIPT=
BACKGROUND_MESSAGE=

setup() {
  test_filter
  SKIP_TEST=('skip-test'
    "load '$_GO_CORE_DIR/lib/bats/background-process'"
    '@test "skip_if_missing_background_utilities" {'
    '  skip_if_missing_background_utilities'
    '  printf "Did not skip" >&2'
    '  return 1'
    '}')

  # The kill-sleep-on-trap trick is from:
  # http://mywiki.wooledge.org/SignalTrap#When_is_the_signal_handled.3F
  BACKGROUND_SCRIPT=('bg-run'
    'printf "%s\n" "Ready..." "Set..." "$BACKGROUND_MESSAGE"'
    "trap 'kill \"\$sleep_pid\"' TERM HUP"
    'sleep 10 &'
    'sleep_pid="$!"'
    'wait "$sleep_pid"')
}

teardown() {
  if [[ -n "$BATS_BACKGROUND_RUN_PID" ]]; then
    kill "$BATS_BACKGROUND_RUN_PID"
    wait
  fi
  unset 'BATS_BACKGROUND_RUN_PID' 'BATS_BACKGROUND_RUN_OUTPUT'
  remove_bats_test_dirs
}

kill_background_test_script() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  kill "$BATS_BACKGROUND_RUN_PID"
  unset 'BATS_BACKGROUND_RUN_PID'
  wait
  restore_bats_shell_options
}

@test "$SUITE: don't skip if all system utilities are present" {
  stub_program_in_path 'pkill'
  stub_program_in_path 'sleep'
  stub_program_in_path 'tail'

  run_bats_test_suite "${SKIP_TEST[@]}"
  restore_programs_in_path 'pkill' 'sleep' 'tail'
  assert_failure
  assert_output_matches 'Did not skip'
}

@test "$SUITE: skip if any system utilities are missing" {
  run_bats_test_suite_in_isolation "${SKIP_TEST[@]}"
  assert_success
  fail_if output_matches 'Did not skip'

  local skip_msg='ok 1 # skip (pkill, sleep, tail not installed on the system)'
  local test_case_name='skip_if_missing_background_utilities'
  assert_lines_equal '1..1' "$skip_msg $test_case_name"
}

@test "$SUITE: run{,_test_script}_in_background launches background process" {
  skip_if_missing_background_utilities
  assert_equal '' "$BATS_BACKGROUND_RUN_OUTPUT"
  assert_equal '' "$BATS_BACKGROUND_RUN_PID"

  export BACKGROUND_MESSAGE='Hello, World!'
  run_test_script_in_background "${BACKGROUND_SCRIPT[@]}"

  assert_equal "$!" "$BATS_BACKGROUND_RUN_PID"
  sleep 0.25
  kill_background_test_script

  assert_equal "$BATS_TEST_ROOTDIR/background-run-output.txt" \
    "$BATS_BACKGROUND_RUN_OUTPUT"
  assert_file_equals "$BATS_BACKGROUND_RUN_OUTPUT" \
    'Ready...' \
    'Set...' \
    "$BACKGROUND_MESSAGE"
}

@test "$SUITE: wait_for_background_output wakes up on expected output" {
  skip_if_missing_background_utilities
  export BACKGROUND_MESSAGE='Hello, World!'
  run_test_script_in_background "${BACKGROUND_SCRIPT[@]}"
  wait_for_background_output "$BACKGROUND_MESSAGE"
  kill_background_test_script
}

@test "$SUITE: wait_for_background fails if run_in_background not called" {
  run wait_for_background_output
  assert_failure 'run_in_background not called'
}

@test "$SUITE: wait_for_background fails if no pattern specified" {
  # Setting BATS_BACKGROUND_RUN_OUTPUT simulates run_in_background here.
  BATS_BACKGROUND_RUN_OUTPUT='foobar' run wait_for_background_output
  assert_failure 'pattern not specified'
}

@test "$SUITE: wait_for_background fails if pattern not seen within timeout" {
  skip_if_missing_background_utilities
  export BACKGROUND_MESSAGE='Goodbye, World!'

  run_test_script_in_background "${BACKGROUND_SCRIPT[@]}"
  run wait_for_background_output 'Hello, World!' '0.25'
  kill_background_test_script

  assert_failure 'Output did not match regular expression:' \
    "  'Hello, World!'" \
    '' \
    'OUTPUT:' \
    '------' \
    'Ready...' \
    'Set...' \
    "$BACKGROUND_MESSAGE"
}

@test "$SUITE: stop_background_run does nothing if no background process" {
  stop_background_run
  assert_success ''
  assert_lines_equal
}

@test "$SUITE: stop_background_run stops the background process and sets vars" {
  skip_if_missing_background_utilities
  export BACKGROUND_MESSAGE='Hello, World!'
  local output_file

  run_test_script_in_background "${BACKGROUND_SCRIPT[@]}"
  output_file="$BATS_BACKGROUND_RUN_OUTPUT"
  wait_for_background_output "$BACKGROUND_MESSAGE"
  stop_background_run

  assert_equal '' "$BATS_BACKGROUND_RUN_PID"
  assert_equal '' "$BATS_BACKGROUND_RUN_OUTPUT"
  if [[ -f "$output_file" ]]; then
    fail "expected BATS_BACKGROUND_RUN_OUTPUT file to be removed: $output_file"
  fi
  assert_status "$((128 + $(kill -l TERM)))"
  assert_equal $'Ready...\nSet...\n'"$BACKGROUND_MESSAGE" "$output"
  assert_lines_equal \
    'Ready...' \
    'Set...' \
    "$BACKGROUND_MESSAGE"
}

@test "$SUITE: stop_background_run sends the specified signal" {
  skip_if_missing_background_utilities
  export BACKGROUND_MESSAGE='Hello, World!'

  run_test_script_in_background "${BACKGROUND_SCRIPT[@]}"
  wait_for_background_output "$BACKGROUND_MESSAGE"
  stop_background_run 'HUP'
  assert_status "$((128 + $(kill -l HUP)))"
}
