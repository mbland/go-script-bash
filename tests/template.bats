#! /usr/bin/env bats

load environment

# By default, the test will try to clone its own repo to avoid flakiness due to
# an external dependency. However, doing so causes a failure on Travis, since it
# uses shallow clones to produce test runs, resulting in the error:
#
#   fatal: attempt to fetch/clone from a shallow repository
#
# However, since Travis already depends on having a good connection to GitHub,
# we'll use the real URL. Alternatively, `git` could be stubbed out via
# `stub_program_in_path` from `_GO_CORE_DIR/lib/bats/helpers`, but the potential
# for neither flakiness nor complexity seems that great, and this approach
# provides extra confidence that the mechanism works as advertised.
#
# A developer can also run the test locally against the real URL by setting
# `TEST_USE_REAL_URL` on the command line. The value of `GO_CORE_URL` is
# subsequently displayed in the name of the test case to validate which repo is
# being used during the test run.
TEST_USE_REAL_URL="${TEST_USE_REAL_URL:-$TRAVIS}"
GO_CORE_URL="${TEST_USE_REAL_URL:+$_GO_CORE_URL}"
GO_CORE_URL="${GO_CORE_URL:-$_GO_CORE_DIR}"

setup() {
  test_filter
  export GO_SCRIPT_BASH_VERSION="$_GO_CORE_VERSION"
  export GO_SCRIPT_BASH_REPO_URL="https://github.com/mbland/go-script-bash.git"
  export GO_SCRIPT_BASH_DOWNLOAD_URL="${GO_SCRIPT_BASH_REPO_URL%.git}/archive"

  # Set up the template to run from `TEST_GO_ROOTDIR`. Add a dummy script to
  # ensure it doesn't return nonzero due to no scripts being present. This will
  # also create `TEST_GO_ROOTDIR` and `TEST_GO_ROOTDIR/scripts`.
  @go.create_test_command_script 'foo' 'printf "%s\n" "Hello, World!"'
  cp "$_GO_CORE_DIR/go-template" "$TEST_GO_ROOTDIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

assert_go_core_unpacked() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  local go_core="$TEST_GO_SCRIPTS_DIR/go-script-bash/go-core.bash"
  local result='0'

  if [[ ! -f "$go_core" ]]; then
    printf "Download did not unpack go-core.bash to: $go_core" >&2
    result='1'
  fi
  restore_bats_shell_options "$result"
}

# Creates a script in `BATS_TEST_BINDIR` to stand in for a program on `PATH`
#
# This enables a test to use `PATH="$BATS_TEST_BINDIR" run ...` to hide programs
# installed on the system to test cases when specific programs can't be found,
# while others remain available.
#
# Creates `BATS_TEST_BINDIR` if it doesn't already exist.
#
# Arguments:
#   program_name:  Name of the system program to forward
create_forwarding_script() {
  local real_program="$(command -v "$1")"
  local forwarding_script="$BATS_TEST_BINDIR/$1"

  if [[ ! -d "$BATS_TEST_BINDIR" ]]; then
    mkdir "$BATS_TEST_BINDIR"
  fi
  printf '%s\n' "#! $BASH" "\"$real_program\" \"\$@\"" >"$forwarding_script"
  chmod 700 "$forwarding_script"
}

@test "$SUITE: successfully run 'help' from its own directory" {
  # Use `_GO_CORE_DIR` to avoid the download attempt in this test.
  GO_SCRIPT_BASH_CORE_DIR="$_GO_CORE_DIR" \
    run "$TEST_GO_ROOTDIR/go-template" 'help'
  assert_success
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
}

@test "$SUITE: download the go-script-bash release from $GO_SCRIPT_BASH_REPO_URL" {
  run "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_failure
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."
  assert_output_matches "Download of '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz' successful."
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked
}

@test "$SUITE: fail to download a nonexistent repo" {
  GO_SCRIPT_BASH_REPO_URL='bogus-repo-that-does-not-exist' \
    GO_SCRIPT_BASH_DOWNLOAD_URL='bogus-url-that-does-not-exist' \
    run "$TEST_GO_ROOTDIR/go-template"
  assert_failure "Downloading framework from 'bogus-url-that-does-not-exist/$GO_SCRIPT_BASH_VERSION.tar.gz'..." \
    "curl: (6) Could not resolve host: bogus-url-that-does-not-exist" \
    "Failed to download from 'bogus-url-that-does-not-exist/$GO_SCRIPT_BASH_VERSION.tar.gz'." \
    "Using git clone as fallback" \
    "Cloning framework from 'bogus-repo-that-does-not-exist'..." \
    "fatal: repository 'bogus-repo-that-does-not-exist' does not exist" \
    "Failed to clone 'bogus-repo-that-does-not-exist'; aborting."
}

@test "$SUITE: fail to download a nonexistent version" {
  GO_SCRIPT_BASH_VERSION='vnonexistent' \
    run "$TEST_GO_ROOTDIR/go-template"
  assert_failure "Downloading framework from 'https://github.com/mbland/go-script-bash/archive/vnonexistent.tar.gz'..." \
    "curl: (22) The requested URL returned error: 404 Not Found" \
    "Failed to download from 'https://github.com/mbland/go-script-bash/archive/vnonexistent.tar.gz'." \
    "Using git clone as fallback" \
    "Cloning framework from 'https://github.com/mbland/go-script-bash.git'..." \
    "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'..." \
    "warning: Could not find remote branch vnonexistent to clone." \
    "fatal: Remote branch vnonexistent not found in upstream origin" \
    "Failed to clone 'https://github.com/mbland/go-script-bash.git'; aborting."
}

@test "$SUITE: fail to find curl uses git clone" {
  create_forwarding_script 'git'
  PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Failed to find cURL or tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to find tar uses git clone" {
  create_forwarding_script 'curl'
  create_forwarding_script 'git'
  PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Failed to find cURL or tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to create directory uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path mkdir "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mkdir

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."

  # Note that the go-template defines `GO_SCRIPTS_DIR`, but the framework's own
  # `go` script doesn't. Hence, we use `TEST_GO_SCRIPTS_RELATIVE_DIR` below,
  # which should always match the default `GO_SCRIPTS_DIR` in the template.
  assert_output_matches \
    "Failed to create scripts dir '$TEST_GO_SCRIPTS_RELATIVE_DIR'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'."
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to move extracted directory uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path mv "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mv

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."
  assert_output_matches "Failed to install downloaded directory in '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}
