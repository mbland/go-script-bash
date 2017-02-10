#! /usr/bin/env bats

load environment

TEST_CLONE_DIR="$TEST_GO_ROOTDIR/scripts/go-script-bash"

setup() {
  test_filter
  mkdir "$TEST_GO_ROOTDIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

create_template_script() {
  local repo_url="$1"
  local version="$2"
  local template="$(< "$_GO_CORE_DIR/go-template")"
  local replacement

  if [[ "$template" =~ GO_SCRIPT_BASH_REPO_URL=[^$'\n']+ ]]; then
    replacement="GO_SCRIPT_BASH_REPO_URL='$repo_url'"
    template="${template/${BASH_REMATCH[0]}/$replacement}"
  fi
  if [[ "$template" =~ GO_SCRIPT_BASH_VERSION=[^$'\n']+ ]]; then
    replacement="GO_SCRIPT_BASH_VERSION='$version'"
    template="${template/${BASH_REMATCH[0]}/$replacement}"
  fi
  printf '%s\n' "$template" > "$TEST_GO_ROOTDIR/go-template"
  chmod 700 "$TEST_GO_ROOTDIR/go-template"
}

@test "$SUITE: clone the go-script-bash repository" {
  create_template_script "$_GO_CORE_DIR" "$_GO_CORE_VERSION"
  run "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_failure
  assert_output_matches "Cloning framework from '$_GO_CORE_DIR'\.\.\."
  assert_output_matches "Cloning into '$TEST_CLONE_DIR'\.\.\."
  assert_output_matches "Clone of '$_GO_CORE_DIR' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  [[ -f "$TEST_GO_ROOTDIR/scripts/go-script-bash/go-core.bash" ]]

  cd "$TEST_GO_ROOTDIR/scripts/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to clone a nonexistent repo" {
  create_template_script 'bogus-repo-that-does-not-exist'
  run "$TEST_GO_ROOTDIR/go-template"
  assert_failure "Cloning framework from 'bogus-repo-that-does-not-exist'..." \
    "fatal: repository 'bogus-repo-that-does-not-exist' does not exist" \
    "Failed to clone 'bogus-repo-that-does-not-exist'; aborting."
}
