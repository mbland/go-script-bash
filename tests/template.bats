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

# Use the same mechanism for testing tarball downloads, since we'll have a
# connection to GitHub in either case.
TEST_ARCHIVE_URL="file://$TEST_GO_ROOTDIR/archive"
GO_ARCHIVE_URL="${TEST_USE_REAL_URL:+$_GO_CORE_URL/archive}"
GO_ARCHIVE_URL="${GO_ARCHIVE_URL:-$TEST_ARCHIVE_URL}"

GO_SCRIPT_BASH_VERSION="$_GO_CORE_VERSION"
GO_SCRIPT_BASH_REPO_URL="$GO_CORE_URL"
GO_SCRIPT_BASH_DOWNLOAD_URL="$GO_ARCHIVE_URL"

RELEASE_TARBALL="${GO_SCRIPT_BASH_VERSION}.tar.gz"
FULL_DOWNLOAD_URL="$GO_SCRIPT_BASH_DOWNLOAD_URL/$RELEASE_TARBALL"

setup() {
  test_filter
  export GO_SCRIPT_BASH_{VERSION,REPO_URL,DOWNLOAD_URL}

  mkdir -p "$TEST_GO_ROOTDIR"
  cp "$_GO_CORE_DIR/go-template" "$TEST_GO_ROOTDIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

assert_go_core_unpacked() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  local go_core="${1:-$TEST_GO_SCRIPTS_DIR/go-script-bash}/go-core.bash"
  local result='0'

  if [[ ! -f "$go_core" ]]; then
    printf "Download did not unpack go-core.bash to: $go_core" >&2
    result='1'
  fi
  restore_bats_shell_options "$result"
}

# This mimics the tarball provided by GitHub.
#
# This could probably become a general-purpose utility one day.
create_fake_tarball_if_not_using_real_url() {
  # We have to trim the leading 'v' from the version string.
  local dirname="go-script-bash-${GO_SCRIPT_BASH_VERSION#v}"
  local full_dir="$TEST_GO_ROOTDIR/$dirname"
  local tarball="${FULL_DOWNLOAD_URL#file://}"

  if [[ -n "$TEST_USE_REAL_URL" ]]; then
    return
  fi

  if ! mkdir -p "${tarball%/*}"; then
    printf 'Failed to create fake archive dir %s\n' "$full_dir" >&2
    return 1
  elif ! mkdir -p "$full_dir"; then
    printf 'Failed to create fake content dir %s\n' "$full_dir" >&2
    return 1
  elif ! tar xf <(tar cf - go-core.bash lib libexec) -C "$full_dir"; then
    printf 'Failed to mirror %s to fake tarball dir %s\n' \
      "$_GO_ROOTDIR" "$full_dir" >&2
    return 1
  elif ! tar cfz "$tarball" -C "$TEST_GO_ROOTDIR" "$dirname"; then
    printf 'Failed to create fake tarball %s\n  from dir %s\n' \
      "$tarball" "$full_dir" >&2
    return 1
  fi
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
  # Set up the template to run from `TEST_GO_ROOTDIR`. Add a dummy script to
  # ensure it doesn't return nonzero due to no scripts being present.
  @go.create_test_command_script 'foo' 'printf "%s\n" "Hello, World!"'

  # Use `_GO_CORE_DIR` to avoid the download attempt in this test.
  GO_SCRIPT_BASH_CORE_DIR="$_GO_CORE_DIR" \
    run "$TEST_GO_ROOTDIR/go-template" 'help'
  assert_success
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
}

@test "$SUITE: download $GO_SCRIPT_BASH_VERSION from $GO_SCRIPT_BASH_REPO_URL" {
  create_fake_tarball_if_not_using_real_url
  run "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_failure
  assert_output_matches "Downloading framework from '$FULL_DOWNLOAD_URL'\.\.\."
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked
}

@test "$SUITE: download into nonstandard GO_SCRIPTS_DIR" {
  local core_dir="$TEST_GO_ROOTDIR/foobar"
  create_fake_tarball_if_not_using_real_url

  # Create a command script in the normal `TEST_GO_SCRIPTS_DIR`.
  @go.create_test_command_script 'foo' 'printf "%s\n" "Hello, World!"'
  GO_SCRIPT_BASH_CORE_DIR="$core_dir" run "$TEST_GO_ROOTDIR/go-template"

  assert_failure
  assert_output_matches "Download of '$FULL_DOWNLOAD_URL' successful."
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked "$core_dir"
}

@test "$SUITE: download uses existing GO_SCRIPTS_DIR" {
  create_fake_tarball_if_not_using_real_url
  mkdir -p "$TEST_GO_SCRIPTS_DIR"
  stub_program_in_path mkdir "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path 'mkdir'

  assert_failure
  assert_output_matches "Download of '$FULL_DOWNLOAD_URL' successful."
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked "$core_dir"
}

@test "$SUITE: fail to download a nonexistent repo" {
  local url='bogus-url-that-does-not-exist'
  local repo='bogus-repo-that-does-not-exist'
  GO_SCRIPT_BASH_DOWNLOAD_URL="$url" GO_SCRIPT_BASH_REPO_URL="$repo" \
    run "$TEST_GO_ROOTDIR/go-template"
  assert_failure "Downloading framework from '$url/$RELEASE_TARBALL'..." \
    "curl: (6) Could not resolve host: $url" \
    "Failed to download from '$url/$RELEASE_TARBALL'." \
    'Using git clone as fallback' \
    "Cloning framework from '$repo'..." \
    "fatal: repository '$repo' does not exist" \
    "Failed to clone '$repo'; aborting."
}

@test "$SUITE: fail to download a nonexistent version" {
  local url="$GO_SCRIPT_BASH_DOWNLOAD_URL/vnonexistent.tar.gz"
  local branch='vnonexistent'
  GO_SCRIPT_BASH_VERSION="$branch" run "$TEST_GO_ROOTDIR/go-template"
  assert_failure
  assert_output_matches 'Using git clone as fallback'
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "warning: Could not find remote branch $branch to clone"
  assert_output_matches "fatal: Remote branch $branch not found in upstream"
  assert_output_matches "Failed to clone '$GO_SCRIPT_BASH_REPO_URL'; aborting."
}

@test "$SUITE: fail to find curl uses git clone" {
  create_forwarding_script 'git'
  PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Failed to find cURL"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches \
    "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
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
  assert_output_matches "Failed to find tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches \
    "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to create directory uses git clone" {
  create_fake_tarball_if_not_using_real_url
  stub_program_in_path mkdir "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mkdir

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '$FULL_DOWNLOAD_URL'\.\.\."

  # Note that the go-template defines `GO_SCRIPTS_DIR`, but the framework's own
  # `go` script doesn't. Hence, we use `TEST_GO_SCRIPTS_RELATIVE_DIR` below,
  # which should always match the default `GO_SCRIPTS_DIR` in the template.
  assert_output_matches "Failed to create scripts dir '$TEST_GO_SCRIPTS_DIR'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'."
  assert_output_matches \
    "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to move extracted directory uses git clone" {
  local target="$TEST_GO_SCRIPTS_DIR/go-script-bash"

  create_fake_tarball_if_not_using_real_url
  stub_program_in_path mv "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mv

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '$FULL_DOWNLOAD_URL'\.\.\."
  assert_output_matches "Failed to install downloaded directory in '$target'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$TEST_GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches \
    "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $TEST_GO_ROOTDIR/go-template <command>"
  assert_go_core_unpacked

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}
