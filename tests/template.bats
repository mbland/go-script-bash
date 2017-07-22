#! /usr/bin/env bats

load environment

# However, since Travis already depends on having a good connection to GitHub,
# we'll use the real URL. Alternatively, `git` could be stubbed out via
# `stub_program_in_path` from `_GO_CORE_DIR/lib/bats/helpers`, but the potential
# for neither flakiness nor complexity seems that great, and this approach

setup() {
  test_filter
  export GO_SCRIPT_BASH_VERSION="$_GO_CORE_VERSION"
  export GO_SCRIPTS_DIR="$_GO_TEST_DIR/tmp/go-template-test-scripts"
  export GO_SCRIPT_BASH_REPO_URL="https://github.com/mbland/go-script-bash.git"
  export GO_SCRIPT_BASH_DOWNLOAD_URL="${GO_SCRIPT_BASH_REPO_URL%.git}/archive"
}

teardown() {
  rm -rf "$_GO_ROOTDIR/$GO_SCRIPTS_DIR"
}

@test "$SUITE: successfully run 'help' from its own directory" {
  GO_SCRIPT_BASH_CORE_DIR="$_GO_CORE_DIR" GO_SCRIPTS_DIR='scripts' \
    run "$_GO_CORE_DIR/go-template" 'help'
  assert_success
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
}

@test "$SUITE: download the go-script-bash release from $GO_SCRIPT_BASH_REPO_URL" {
  run "$_GO_CORE_DIR/go-template"

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_failure
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."

  # Use `.*/scripts/go-script-bash` to account for the fact that `git clone` on
  # MSYS2 will output `C:/Users/<user>/AppData/Local/Temp/` in place of `/tmp`.
  assert_output_matches "Download of '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz' successful."
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
  [[ -f "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash/go-core.bash" ]]

}

@test "$SUITE: fail to download a nonexistent repo" {
  GO_SCRIPT_BASH_REPO_URL='bogus-repo-that-does-not-exist' \
    GO_SCRIPT_BASH_DOWNLOAD_URL='bogus-url-that-does-not-exist' \
    run "$_GO_CORE_DIR/go-template"
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
    run "$_GO_CORE_DIR/go-template"
  assert_failure "Downloading framework from 'https://github.com/mbland/go-script-bash/archive/vnonexistent.tar.gz'..." \
    "curl: (22) The requested URL returned error: 404 Not Found" \
    "Failed to download from 'https://github.com/mbland/go-script-bash/archive/vnonexistent.tar.gz'." \
    "Using git clone as fallback" \
    "Cloning framework from 'https://github.com/mbland/go-script-bash.git'..." \
    "Cloning into '$PWD/$GO_SCRIPTS_DIR/go-script-bash'..." \
    "warning: Could not find remote branch vnonexistent to clone." \
    "fatal: Remote branch vnonexistent not found in upstream origin" \
    "Failed to clone 'https://github.com/mbland/go-script-bash.git'; aborting."
}

@test "$SUITE: fail to find curl uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path curl "exit 1"
  run "$_GO_CORE_DIR/go-template"
  restore_program_in_path curl

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Failed to find cURL or tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'\.\.\."

  # Use `.*/scripts/go-script-bash` to account for the fact that `git clone` on
  # MSYS2 will output `C:/Users/<user>/AppData/Local/Temp/` in place of `/tmp`.
  assert_output_matches "Cloning into '.*/$GO_SCRIPTS_DIR/go-script-bash'\.\.\."
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
  [[ -f "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash/go-core.bash" ]]

  cd "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to find tar uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path tar "exit 1"
  run "$_GO_CORE_DIR/go-template"
  restore_program_in_path tar

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Failed to find cURL or tar"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'\.\.\."

  # Use `.*/scripts/go-script-bash` to account for the fact that `git clone` on
  # MSYS2 will output `C:/Users/<user>/AppData/Local/Temp/` in place of `/tmp`.
  assert_output_matches "Cloning into '.*/$GO_SCRIPTS_DIR/go-script-bash'\.\.\."
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
  [[ -f "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash/go-core.bash" ]]

  cd "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to create directory uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path mkdir "exit 1"
  run "$_GO_CORE_DIR/go-template"
  restore_program_in_path mkdir

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."
  assert_output_matches "Failed to create scripts dir '$GO_SCRIPTS_DIR'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'\.\.\."

  # Use `.*/scripts/go-script-bash` to account for the fact that `git clone` on
  # MSYS2 will output `C:/Users/<user>/AppData/Local/Temp/` in place of `/tmp`.
  assert_output_matches "Cloning into '.*/$GO_SCRIPTS_DIR/go-script-bash'\.\.\."
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
  [[ -f "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash/go-core.bash" ]]

  cd "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}

@test "$SUITE: fail to move extracted directory uses git clone" {
  PATH="$BATS_TEST_BINDIR:$PATH" 
  stub_program_in_path mv "exit 1"
  run "$_GO_CORE_DIR/go-template"
  restore_program_in_path mv

  # Without a command argument, the script will print the top-level help and
  # return an error, but the core repo should exist as expected.
  assert_output_matches "Downloading framework from '${GO_SCRIPT_BASH_REPO_URL%.git}.*.tar.gz'\.\.\."
  assert_output_matches "Failed to install downloaded directory in '.*/$GO_SCRIPTS_DIR/go-script-bash'"
  assert_output_matches "Using git clone as fallback"
  assert_output_matches "Cloning framework from '$GO_SCRIPT_BASH_REPO_URL'\.\.\."

  # Use `.*/scripts/go-script-bash` to account for the fact that `git clone` on
  # MSYS2 will output `C:/Users/<user>/AppData/Local/Temp/` in place of `/tmp`.
  assert_output_matches "Cloning into '.*/$GO_SCRIPTS_DIR/go-script-bash'\.\.\."
  assert_output_matches "Clone of '$GO_SCRIPT_BASH_REPO_URL' successful\."$'\n\n'
  assert_output_matches "Usage: $_GO_CORE_DIR/go-template <command>"
  [[ -f "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash/go-core.bash" ]]

  cd "$_GO_ROOTDIR/$GO_SCRIPTS_DIR/go-script-bash"
  run git log --oneline -n 1
  assert_success
  assert_output_matches "go-script-bash $_GO_CORE_VERSION"
}