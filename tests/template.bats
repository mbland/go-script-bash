#! /usr/bin/env bats

load environment
load "$_GO_CORE_DIR/lib/portability"

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
TEST_ARCHIVE_DIR="$TEST_GO_ROOTDIR/archive"
TEST_ARCHIVE_URL="file://$TEST_ARCHIVE_DIR"
GO_ARCHIVE_URL="${TEST_USE_REAL_URL:+$_GO_CORE_URL/archive}"
GO_ARCHIVE_URL="${GO_ARCHIVE_URL:-$TEST_ARCHIVE_URL}"

GO_SCRIPT_BASH_VERSION="$_GO_CORE_VERSION"
GO_SCRIPT_BASH_REPO_URL="$GO_CORE_URL"
GO_SCRIPT_BASH_DOWNLOAD_URL="$GO_ARCHIVE_URL"

RELEASE_TARBALL="${GO_SCRIPT_BASH_VERSION}.tar.gz"
FULL_DOWNLOAD_URL="$GO_SCRIPT_BASH_DOWNLOAD_URL/$RELEASE_TARBALL"
LOCAL_DOWNLOAD_URL="$TEST_ARCHIVE_URL/$RELEASE_TARBALL"
NATIVE_LOCAL_URL=
EXPECTED_URL=
CLONE_DIR=

setup() {
  test_filter
  export GO_SCRIPT_BASH_{VERSION,REPO_URL,DOWNLOAD_URL}
  @go.native_file_path_or_url 'NATIVE_LOCAL_URL' "$LOCAL_DOWNLOAD_URL"
  @go.native_file_path_or_url 'CLONE_DIR' "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  EXPECTED_URL="$FULL_DOWNLOAD_URL"

  if [[ -z "$TEST_USE_REAL_URL" ]]; then
    EXPECTED_URL="$NATIVE_LOCAL_URL"
  fi

  # Ensure `cygpath` and `git` are always available if we need them.
  create_forwarding_script 'cygpath'
  create_forwarding_script 'git'

  cp "$_GO_CORE_DIR/go-template" "$TEST_GO_ROOTDIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

# This mimics the tarball provided by GitHub.
#
# This could probably become a general-purpose utility one day.
create_fake_tarball_if_not_using_real_url() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  _create_fake_tarball_if_not_using_real_url
  restore_bats_shell_options "$?"
}

_create_fake_tarball_if_not_using_real_url() {
  # We have to trim the leading 'v' from the version string.
  local dirname="go-script-bash-${GO_SCRIPT_BASH_VERSION#v}"
  local tarball="${LOCAL_DOWNLOAD_URL#file://}"
  local full_dir="${TEST_ARCHIVE_DIR}/${dirname}"
  local result='0'

  if [[ -n "$TEST_USE_REAL_URL" ]]; then
    restore_bats_shell_options
  fi

  . "$_GO_USE_MODULES" 'fileutil'
  @go.mirror_directory "$_GO_CORE_DIR" "$full_dir" \
    'go-core.bash' 'lib' 'libexec'

  if ! tar -czf "$tarball" -C "$TEST_ARCHIVE_DIR" "$dirname"; then
    printf 'Failed to create fake tarball %s\n  from dir %s\n' \
      "$tarball" "$full_dir" >&2
    return '1'
  fi
}

# Used to mimic each of curl, wget, and fetch while testing downloads.
#
# This way we can test all of the download program selection logic regardless of
# what's installed on the host.
run_with_download_program() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  local download_program="$1"

  # This isn't a useless use of cat; it's the easiest way to stream raw bytes
  # from the input file to standard output, as $(< $filename) doesn't handle
  # them properly.
  stub_program_in_path "$download_program" \
    'filename="${@:$#}"' \
    "\"$(command -v cat)\" \"\${filename#file://}\""

  create_forwarding_script 'bash'
  create_forwarding_script 'tar'
  create_forwarding_script 'gzip'
  create_forwarding_script 'mkdir'
  create_forwarding_script 'mv'

  # We're forcing a local tarball "download" here.
  TEST_USE_REAL_URL= create_fake_tarball_if_not_using_real_url
  GO_SCRIPT_BASH_DOWNLOAD_URL="$TEST_ARCHIVE_URL" \
    PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"
  restore_bats_shell_options
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

@test "$SUITE: download $GO_SCRIPT_BASH_VERSION from $FULL_DOWNLOAD_URL" {
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'tar'
  create_fake_tarball_if_not_using_real_url

  run "$TEST_GO_ROOTDIR/go-template"
  assert_output_matches "Downloading framework from '$EXPECTED_URL'\.\.\."
  assert_output_matches "Download of '$EXPECTED_URL' successful."
}

@test "$SUITE: download locally using curl" {
  skip_if_system_missing 'tar'
  run_with_download_program 'curl'
  assert_output_matches "Downloading framework from '$NATIVE_LOCAL_URL'\.\.\."
  assert_output_matches "Download of '$NATIVE_LOCAL_URL' successful."
}

@test "$SUITE: download locally using fetch" {
  skip_if_system_missing 'tar'
  run_with_download_program 'fetch'
  assert_output_matches "Downloading framework from '$NATIVE_LOCAL_URL'\.\.\."
  assert_output_matches "Download of '$NATIVE_LOCAL_URL' successful."
}

@test "$SUITE: download locally using cat" {
  skip_if_system_missing 'tar'
  # We'll actually use `cat` with `file://` URLs, since `wget` only supports
  # HTTP, HTTPS, and FTP.
  run_with_download_program 'cat'
  assert_output_matches "Downloading framework from '$NATIVE_LOCAL_URL'\.\.\."
  assert_output_matches "Download of '$NATIVE_LOCAL_URL' successful."
}

@test "$SUITE: download locally using wget" {
  skip_if_system_missing 'tar'
  # As mentioned in the above test case, we'll actually use `cat` with `file://`
  # URLs, but we're simulating `wget` by pretending `cat` doesn't exist.
  run_with_download_program 'wget'
  assert_output_matches "Downloading framework from '$NATIVE_LOCAL_URL'\.\.\."
  assert_output_matches "Download of '$NATIVE_LOCAL_URL' successful."
}

@test "$SUITE: download into nonstandard GO_SCRIPTS_DIR" {
  local core_dir="$TEST_GO_ROOTDIR/foobar"
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'tar'
  create_fake_tarball_if_not_using_real_url

  # Create a command script in the normal `TEST_GO_SCRIPTS_DIR`.
  @go.create_test_command_script 'foo' 'printf "%s\n" "Hello, World!"'
  GO_SCRIPT_BASH_CORE_DIR="$core_dir" run "$TEST_GO_ROOTDIR/go-template"
  assert_output_matches "Download of '$EXPECTED_URL' successful."
}

@test "$SUITE: download uses existing GO_SCRIPTS_DIR" {
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'tar'
  create_fake_tarball_if_not_using_real_url
  mkdir -p "$TEST_GO_SCRIPTS_DIR"
  stub_program_in_path mkdir "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path 'mkdir'

  assert_output_matches "Download of '$EXPECTED_URL' successful."
}

@test "$SUITE: fail to download a nonexistent repo" {
  local url="$GO_SCRIPT_BASH_DOWNLOAD_URL/bogus-url-that-does-not-exist"
  local repo='bogus-repo-that-does-not-exist'

  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git' 'tar'

  GO_SCRIPT_BASH_DOWNLOAD_URL="$url" GO_SCRIPT_BASH_REPO_URL="$repo" \
    run "$TEST_GO_ROOTDIR/go-template"

  @go.native_file_path_or_url 'url' "$url"
  assert_output_matches "Downloading framework from '$url/$RELEASE_TARBALL'"
  assert_output_matches "Failed to download from '$url/$RELEASE_TARBALL'"
  assert_output_matches 'Using git clone as fallback'
  assert_output_matches "Cloning framework from '$repo'"
  assert_output_matches "fatal: repository '$repo' does not exist"
  assert_output_matches "Failed to clone '$repo'; aborting."
}

@test "$SUITE: fail to download a nonexistent version" {
  local url="$GO_SCRIPT_BASH_DOWNLOAD_URL"
  local branch='vnonexistent'

  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git' 'tar'
  GO_SCRIPT_BASH_VERSION="$branch" run "$TEST_GO_ROOTDIR/go-template"

  @go.native_file_path_or_url 'url' "$url"
  assert_output_matches "Downloading framework from '$url/${branch}.tar.gz'"
  assert_output_matches "Failed to download from '$url/${branch}.tar.gz'"
  assert_output_matches 'Using git clone as fallback'
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "warning: Could not find remote branch $branch to clone"
  assert_output_matches "fatal: Remote branch $branch not found in upstream"
  assert_output_matches "Failed to clone '$GO_SCRIPT_BASH_REPO_URL'; aborting."
}

@test "$SUITE: use git clone if GO_SCRIPT_BASH_DOWNLOAD_URL lacks a protocol" {
  local url='bogus-url-with-no-protocol'

  skip_if_system_missing 'git'
  GO_SCRIPT_BASH_DOWNLOAD_URL="$url" run "$TEST_GO_ROOTDIR/go-template"

  assert_output_matches "GO_SCRIPT_BASH_DOWNLOAD_URL has no protocol: $url"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."

  cd "$TEST_GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to find download program uses git clone" {
  skip_if_system_missing 'git'
  PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"

  assert_output_matches "Failed to find cURL, wget, or fetch"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."
}

@test "$SUITE: fail to find tar uses git clone" {
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git'
  create_forwarding_script 'curl'
  create_forwarding_script 'wget'
  create_forwarding_script 'fetch'
  PATH="$BATS_TEST_BINDIR" run "$BASH" "$TEST_GO_ROOTDIR/go-template"

  assert_output_matches "Failed to find tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."
}

@test "$SUITE: tar failure uses git clone" {
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git' 'tar'

  TEST_USE_REAL_URL= create_fake_tarball_if_not_using_real_url
  stub_program_in_path 'tar' \
    "$(command -v 'tar') \"\$@\"" \
    'exit 1'

  GO_SCRIPT_BASH_DOWNLOAD_URL="$TEST_ARCHIVE_URL" \
    run "$BASH" "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path 'tar'

  assert_output_matches "Downloading framework from '$NATIVE_LOCAL_URL'\.\.\."
  assert_output_matches "Failed to download from '$NATIVE_LOCAL_URL'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."
}

@test "$SUITE: fail to create directory uses git clone" {
  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git' 'tar'
  create_fake_tarball_if_not_using_real_url
  stub_program_in_path mkdir "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mkdir

  assert_output_matches "Downloading framework from '$EXPECTED_URL'\.\.\."

  # Note that the go-template defines `GO_SCRIPTS_DIR`, but the framework's own
  # `go` script doesn't. Hence, we use `TEST_GO_SCRIPTS_RELATIVE_DIR` below,
  # which should always match the default `GO_SCRIPTS_DIR` in the template.
  assert_output_matches "Failed to create scripts dir '$TEST_GO_SCRIPTS_DIR'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."
}

@test "$SUITE: fail to move extracted directory uses git clone" {
  local target="$TEST_GO_SCRIPTS_DIR/go-script-bash"

  skip_if_none_present_on_system 'curl' 'fetch' 'wget'
  skip_if_system_missing 'git' 'tar'
  create_fake_tarball_if_not_using_real_url
  stub_program_in_path mv "exit 1"
  run "$TEST_GO_ROOTDIR/go-template"
  restore_program_in_path mv

  assert_output_matches "Downloading framework from '$EXPECTED_URL'\.\.\."
  assert_output_matches "Failed to install downloaded directory in '$target'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'"
  assert_output_matches "Cloning into '$CLONE_DIR'"
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."
}
