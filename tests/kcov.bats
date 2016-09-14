#! /usr/bin/env bats

load environment
load assertions
load script_helper

FAKE_BIN_DIR="$TEST_GO_ROOTDIR/fake-bin"

setup() {
  local fake_binaries=(
    'apt-get'
    'cmake'
    'git'
    'sudo'
    'make'
    'dpkg-query')
  local fake_binary

  mkdir -p "$FAKE_BIN_DIR"

  for fake_binary in "${fake_binaries[@]/#/$FAKE_BIN_DIR/}"; do
    echo '#! /usr/bin/env bash' >"$fake_binary"
    echo 'echo "$@" >"$0.out" 2>&1' >>"$fake_binary"
  done
  chmod 700 "$FAKE_BIN_DIR"/*
}

teardown() {
  remove_test_go_rootdir
}

write_kcov_go_script() {
  local go_script=(
    ". \"$_GO_ROOTDIR/scripts/lib/kcov\""
    "PATH=\"$FAKE_BIN_DIR:\$PATH\""
    "$@")
  create_test_go_script "${go_script[@]}"
}

@test "$SUITE: check dev packages installed" {
  write_kcov_go_script check_kcov_dev_packages_installed
  run "$TEST_GO_SCRIPT"
  assert_success ''

  run cat "$FAKE_BIN_DIR/dpkg-query.out"
  . 'scripts/lib/kcov'
  assert_success "-W -f=\${Package} \${Status}\\n ${KCOV_DEV_PACKAGES[*]}"
}

@test "$SUITE: check dev packages fails on dpkg-query error" {
  write_kcov_go_script check_kcov_dev_packages_installed
  echo 'exit 1' >>"$FAKE_BIN_DIR/dpkg-query"
  run "$TEST_GO_SCRIPT"
  assert_failure ''
}

@test "$SUITE: check dev packages fails if a package deinstalled" {
  write_kcov_go_script check_kcov_dev_packages_installed
  echo 'echo deinstall' >>"$FAKE_BIN_DIR/dpkg-query"
  run "$TEST_GO_SCRIPT"
  assert_failure ''
}

@test "$SUITE: clone and build" {
  local go_script=(
    'check_kcov_dev_packages_installed() { return 1; }'
    'clone_and_build_kcov tests/kcov')
  local IFS=$'\n'
  write_kcov_go_script "${go_script[*]}"
  echo 'mkdir -p "$3"' >> "$FAKE_BIN_DIR/git"

  run "$TEST_GO_SCRIPT"
  . 'scripts/lib/kcov'
  local expected_output=(
    "Cloning kcov repository from $KCOV_URL..."
    'Installing dev packages to build kcov...'
    'Building kcov...')
  assert_success "${expected_output[*]}"

  run cat "$FAKE_BIN_DIR/git.out"
  assert_success "clone $KCOV_URL tests/kcov"

  run cat "$FAKE_BIN_DIR/sudo.out"
  IFS=' '
  assert_success "apt-get install -y ${KCOV_DEV_PACKAGES[*]}"

  run cat "$FAKE_BIN_DIR/cmake.out"
  assert_success 'tests/kcov'

  run cat "$FAKE_BIN_DIR/make.out"
  assert_success '-C tests/kcov'
}

@test "$SUITE: clone and build fails if clone fails" {
  write_kcov_go_script 'clone_and_build_kcov tests/kcov'
  echo 'exit 1' >> "$FAKE_BIN_DIR/git"

  run "$TEST_GO_SCRIPT"
  . 'scripts/lib/kcov'
  local expected_output=(
    "Cloning kcov repository from $KCOV_URL..."
    "Failed to clone $KCOV_URL into tests/kcov.")
  local IFS=$'\n'
  assert_failure "${expected_output[*]}"
}

@test "$SUITE: clone and build fails if install fails" {
  write_kcov_go_script 'clone_and_build_kcov tests/kcov'
  echo 'exit 1' >>"$FAKE_BIN_DIR/dpkg-query"
  echo 'exit 1' >> "$FAKE_BIN_DIR/sudo"
  mkdir -p "$TEST_GO_ROOTDIR/tests/kcov"

  run "$TEST_GO_SCRIPT"
  . 'scripts/lib/kcov'
  local expected_output=(
    'Installing dev packages to build kcov...'
    'Failed to install dev packages needed to build kcov.')
  local IFS=$'\n'
  assert_failure "${expected_output[*]}"
}

@test "$SUITE: clone and build fails if cmake fails" {
  write_kcov_go_script 'clone_and_build_kcov tests/kcov'
  mkdir -p "$TEST_GO_ROOTDIR/tests/kcov"
  echo 'exit 1' >> "$FAKE_BIN_DIR/cmake"

  run "$TEST_GO_SCRIPT"
  . 'scripts/lib/kcov'
  local expected_output=(
    'Building kcov...'
    'Failed to build kcov.')
  local IFS=$'\n'
  assert_failure "${expected_output[*]}"
}

@test "$SUITE: clone and build fails if make fails" {
  write_kcov_go_script 'clone_and_build_kcov tests/kcov'
  mkdir -p "$TEST_GO_ROOTDIR/tests/kcov"
  echo 'exit 1' >> "$FAKE_BIN_DIR/make"

  run "$TEST_GO_SCRIPT"
  . 'scripts/lib/kcov'
  local expected_output=(
    'Building kcov...'
    'Failed to build kcov.')
  local IFS=$'\n'
  assert_failure "${expected_output[*]}"
}

@test "$SUITE: clone and build doesn't install dev packages on Travis" {
  local go_script=(
    'check_kcov_dev_packages_installed() { return 1; }'
    'clone_and_build_kcov tests/kcov')
  local IFS=$'\n'
  write_kcov_go_script "${go_script[*]}"

  mkdir -p "$TEST_GO_ROOTDIR/tests/kcov"
  run env TRAVIS_OS_NAME='linux' "$TEST_GO_SCRIPT"
  assert_success 'Building kcov...'
}
