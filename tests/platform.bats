#! /usr/bin/env bats

load environment

PLATFORM_TEST_SCRIPT=

setup() {
  unset "${!_GO_PLATFORM_@}"
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "platform"' \
    'for var in "${!_GO_PLATFORM_@}"; do' \
    '  printf "%s=\"%s\"\n" "$var" "${!var}"' \
    'done'
  export __GO_ETC_OS_RELEASE="$BATS_TEST_ROOTDIR/os-release"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: leave _GO_PLATFORM_ID unchanged if already set" {
  _GO_PLATFORM_ID='foobar' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="foobar"'
}

@test "$SUITE: set _GO_PLATFORM_* variables from /etc/os-release" {
  mkdir -p "$BATS_TEST_ROOTDIR"
  printf '%s\n' \
    'NAME="Foo Bar"' \
    'ID=foobar' \
    'VERSION_ID=666' >"$__GO_ETC_OS_RELEASE"

  run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="foobar"' \
    '_GO_PLATFORM_NAME="Foo Bar"' \
    '_GO_PLATFORM_VERSION_ID="666"'
}

@test "$SUITE: set _GO_PLATFORM_ID from OSTYPE" {
  OSTYPE='foobar' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="foobar"'
}

@test "$SUITE: set _GO_PLATFORM_ID to macos from OSTYPE" {
  OSTYPE='darwin16' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="macos"'
}

@test "$SUITE: set _GO_PLATFORM_ID to freebsd from OSTYPE" {
  OSTYPE='freebsd11.0' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="freebsd"'
}

@test "$SUITE: set _GO_PLATFORM_ID to msys from OSTYPE" {
  stub_program_in_path 'git' 'printf "%s\n" "git version 2.13.0"'
  OSTYPE='msys' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="msys"'
}

@test "$SUITE: set _GO_PLATFORM_ID to msys-git from OSTYPE and git --version" {
  stub_program_in_path 'git' 'printf "%s\n" "git version 2.13.0.windows.1"'
  OSTYPE='msys' run "$TEST_GO_SCRIPT"
  assert_success '_GO_PLATFORM_ID="msys-git"'
}
