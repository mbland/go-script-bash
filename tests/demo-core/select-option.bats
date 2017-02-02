#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  export PS3='Selection> '
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: use default selection options" {
  run "$_GO_SCRIPT" demo-core select-option <<<$'1\n1\n2\n2\n'
  assert_success
  split_bats_output_into_lines
  assert_lines_equal 'Please select one of the following options:' \
    '1) Hello, World!' \
    '2) Goodbye, World!' \
    "${PS3}You selected: \"Hello, World!\"" \
    '' \
    'Would you like to select another option?' \
    '1) Yes' \
    '2) No' \
    "${PS3}" \
    'Please select one of the following options:' \
    '1) Hello, World!' \
    '2) Goodbye, World!' \
    "${PS3}You selected: \"Goodbye, World!\"" \
    '' \
    'Would you like to select another option?' \
    '1) Yes' \
    '2) No' \
    "${PS3}Exiting..."
}

@test "$SUITE: use user-provided selection options" {
  run "$_GO_SCRIPT" demo-core select-option foo bar baz <<<$'2\n2\n'
  assert_success
  split_bats_output_into_lines
  assert_lines_equal 'Please select one of the following options:' \
    '1) foo' \
    '2) bar' \
    '3) baz' \
    "${PS3}You selected: \"bar\"" \
    '' \
    'Would you like to select another option?' \
    '1) Yes' \
    '2) No' \
    "${PS3}Exiting..."
}

@test "$SUITE: exit both prompts on empty input" {
  mkdir "$TEST_GO_ROOTDIR"
  printf '' >"$TEST_GO_ROOTDIR/input.txt"
  run "$_GO_SCRIPT" demo-core select-option foo bar baz \
    <"$TEST_GO_ROOTDIR/input.txt"

  assert_success
  split_bats_output_into_lines
  assert_lines_equal 'Please select one of the following options:' \
    '1) foo' \
    '2) bar' \
    '3) baz' \
    "${PS3}" \
    'You declined to select an option.' \
    '' \
    'Would you like to select another option?' \
    '1) Yes' \
    '2) No' \
    "${PS3}" \
    'You declined to select an option. Exiting...'
}
