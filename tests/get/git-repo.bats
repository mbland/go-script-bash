#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script '@go "$@"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: show help if not exactly three args" {
  run test-go get git-repo
  assert_failure
  assert_output_matches "^test-go get git-repo - Creates a shallow clone"
}

@test "$SUITE: tab completion" {
  run "$TEST_GO_SCRIPT" get git-repo --complete 0
  assert_success ''

  run "$TEST_GO_SCRIPT" get git-repo --complete 1
  assert_success ''

  local expected=("$TEST_GO_ROOTDIR"/*)
  test_join $'\n' expected "${expected[@]#$TEST_GO_ROOTDIR/}"

  run "$TEST_GO_SCRIPT" get git-repo --complete 2
  assert_success "$expected"
}

@test "$SUITE: fail if git not installed" {
  PATH= run "$BASH" "$TEST_GO_SCRIPT" get git-repo foobar.git v1.0.0 foo/bar
  assert_failure 'Please install git before running "get git-repo".'
}

@test "$SUITE: fail if target directory already exists" {
  stub_program_in_path 'git' 'echo Should not see this!' 'exit 1'
  mkdir -p "$TEST_GO_ROOTDIR/foo/bar"
  run "$TEST_GO_SCRIPT" get git-repo foobar.git v1.0.0 foo/bar
  assert_failure '"foo/bar" already exists; not updating.'
}

@test "$SUITE: git called with the correct arguments" {
  stub_program_in_path 'git' 'printf "%s\n" "$*"'
  run "$TEST_GO_SCRIPT" get git-repo foobar.git v1.0.0 foo/bar

  local expected=('clone -q -c advice.detachedHead=false --depth 1'
    '-b v1.0.0 foobar.git foo/bar')
  assert_success "${expected[*]}" \
    'Successfully cloned "foobar.git" reference "v1.0.0" into "foo/bar".'
}

@test "$SUITE: git fails to clone the repo" {
  stub_program_in_path 'git' 'exit 1'
  run "$TEST_GO_SCRIPT" get git-repo foobar.git v1.0.0 foo/bar

  local expected=('Failed to clone "foobar.git" reference "v1.0.0"'
    'into "foo/bar".')
  assert_failure "${expected[*]}"
}

@test "$SUITE: use the real git to clone the framework repo" {
  if ! command -v git >/dev/null; then
    skip "git not installed on the system"
  fi

  run "$TEST_GO_SCRIPT" get git-repo "$_GO_CORE_DIR" v1.3.0 go-core

  # Note that we add a `file://` prefix to local repositories.
  local expected=("Successfully cloned \"file://$_GO_CORE_DIR\""
    'reference "v1.3.0" into "go-core".')
  assert_success "${expected[*]}"

  [ -d "$TEST_GO_ROOTDIR/go-core/.git" ]
  cd "$TEST_GO_ROOTDIR/go-core"

  run git log --oneline
  assert_success 'daa9f5d go-script-bash v1.3.0'
}
