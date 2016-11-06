#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  create_test_go_script '@go "$@"'
  setup_test_modules
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: zero arguments" {
  run "$TEST_GO_SCRIPT" modules --complete
  local expected=('-h' '-help' '--help' '--paths' '--summaries' '--imported'
    "${CORE_MODULES[@]}" "${TEST_PROJECT_MODULES[@]}" "${TEST_PLUGINS[@]/%//}")
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: first argument matches help flags" {
  run "$TEST_GO_SCRIPT" modules --complete 0 -h _foo
  local expected=('-h' '-help')
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: first argument matches modules" {
  run "$TEST_GO_SCRIPT" modules --complete 0 _f
  local expected=('_frobozz' '_frotz' '_foo/')
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: only complete first flag" {
  run "$TEST_GO_SCRIPT" modules --complete 0 --pat --sum
  assert_success '--paths'

  run "$TEST_GO_SCRIPT" modules --complete 1 --paths --sum
  assert_failure ''
}

@test "$SUITE: only complete flag as first arg" {
  run "$TEST_GO_SCRIPT" modules --complete 1 foo --pat
  assert_failure ''
}

@test "$SUITE: nothing else when --imported present" {
  run "$TEST_GO_SCRIPT" modules --complete 1 --imported foo
  assert_failure ''
}

@test "$SUITE: nothing else when first flag not recognized" {
  run "$TEST_GO_SCRIPT" modules --complete 1 --bogus-flag foo
  assert_failure ''
}

@test "$SUITE: return plugin dirs, core and project modules for flag" {
  # Note that plugins are offered last
  local expected=(
    "${CORE_MODULES[@]}" "${TEST_PROJECT_MODULES[@]}" "${TEST_PLUGINS[@]/%//}")
  run "$TEST_GO_SCRIPT" modules --complete 1 --help
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: return matching plugins and modules" {
  local expected=('_frobozz' '_frotz' '_foo/')
  run "$TEST_GO_SCRIPT" modules --complete 1 help '_f'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: return only matching plugin names" {
  local expected=('_bar/' '_baz/')
  run "$TEST_GO_SCRIPT" modules --complete 1 help '_b'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: return all matches for a plugin when no other matches" {
  local expected=('_foo/_plugh' '_foo/_quux' '_foo/_xyzzy')
  run "$TEST_GO_SCRIPT" modules --complete 1 help '_fo'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: return matches for a plugin when arg ends with a slash" {
  local expected=('_baz/_plugh' '_baz/_quux' '_baz/_xyzzy')
  run "$TEST_GO_SCRIPT" modules --complete 1 help '_baz/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: no matches" {
  run "$TEST_GO_SCRIPT" modules --complete 1 help '_x'
  assert_failure ''
}

@test "$SUITE: complete only first argument for help" {
  run "$TEST_GO_SCRIPT" modules --complete 2 --help '_frobozz' '_fr'
  assert_failure ''
}

@test "$SUITE: complete subsequent args for flags other than help" {
  # Note that matches already on command line are not completed.
  run "$TEST_GO_SCRIPT" modules --complete 2 --paths '_frobozz' '_fr'
  assert_success '_frotz'
}

@test "$SUITE: complete subsequent args if first arg not a flag" {
  # Note that matches already on command line are not completed.
  run "$TEST_GO_SCRIPT" modules --complete 1 '_frobozz' '_fr'
  assert_success '_frotz'
}

@test "$SUITE: remove plugin completions already present" {
  local expected=('_foo/_quux' '_foo/_xyzzy')
  run "$TEST_GO_SCRIPT" modules --complete 1 '_foo/_plugh' '_foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: don't complete plugins when all modules already present" {
  local expected=("${CORE_MODULES[@]}" '_frobozz' '_frotz' '_bar/' '_baz/')
  run "$TEST_GO_SCRIPT" modules --complete 3 \
    '_foo/_plugh' '_foo/_quux' '_foo/_xyzzy'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
