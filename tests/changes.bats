#! /usr/bin/env bats

load environment

setup() {
  mkdir -p "$TEST_GO_ROOTDIR/bin" "$TEST_GO_SCRIPTS_DIR"
}

teardown() {
  remove_test_go_rootdir
}

create_fake_git() {
  local fake_git_path="$TEST_GO_ROOTDIR/bin/git"
  local fake_git_impl=('#! /usr/bin/env bash' "$@")
  local IFS=$'\n'

  echo "${fake_git_impl[*]}" >"$fake_git_path"
  chmod 700 "$fake_git_path"
}

@test "$SUITE: tab completions" {
  local versions=('v1.0.0' 'v1.1.0')
  local IFS=$'\n'
  local fake_git_impl=(
    "if [[ \"\$1\" == 'tag' ]]; then"
    "  echo '${versions[*]}'"
    '  exit 0'
    'fi'
    'exit 1'
  )

  create_fake_git "${fake_git_impl[@]}"
  run "$TEST_GO_ROOTDIR/bin/git" 'tag'
  assert_success "${versions[*]}"

  local PATH="$TEST_GO_ROOTDIR/bin:$PATH"
  run ./go changes --complete 0 ''
  assert_success "${versions[*]}"

  run ./go changes --complete 0 'v1.0'
  assert_success 'v1.0.0'

  run ./go changes --complete 1 'v1.0.0' 'v1.1'
  assert_success 'v1.1.0'

  run ./go changes --complete 2 'v1.0.0' 'v1.1.0' ''
  assert_failure ''
}

@test "$SUITE: error if no start ref" {
  run ./go changes
  assert_failure "Start ref not specified."
}

@test "$SUITE: error if no end ref" {
  run ./go changes v1.0.0
  assert_failure "End ref not specified."
}

@test "$SUITE: git log call is well-formed" {
  local IFS=$'\n'
  local fake_git_impl=(
    "if [[ \"\$1\" == 'log' ]]; then"
    '  shift'
    "  IFS=\$'\\n'"
    '  echo "$*"'
    '  exit 0'
    'fi'
    'exit 1'
  )

  create_fake_git "${fake_git_impl[@]}"
  local PATH="$TEST_GO_ROOTDIR/bin:$PATH"
  run ./go changes v1.0.0 v1.1.0
  assert_success
  assert_line_matches 0 '^--pretty=format:'
  assert_line_matches 1 '^v1\.0\.0\.\.v1\.1\.0\^$'
}
