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

  stub_program_in_path 'sw_vers' \
    'if [[ "$*" == "-productVersion" ]]; then' \
    '  printf "$TEST_MACOS_VERSION\n"' \
    'fi'

  stub_program_in_path 'uname' \
    'if [[ "$*" == "-r" ]]; then' \
    '  printf "$TEST_UNAME_VERSION\n"' \
    'fi'

  stub_program_in_path 'git' \
    'if [[ "$*" == "--version" ]]; then' \
    '  printf "git version %s\n" "$TEST_GIT_VERSION"' \
    'fi'
}

teardown() {
  restore_programs_in_path 'git' 'uname' 'sw_vers'
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

@test "$SUITE: set _GO_PLATFORM_{ID,VERSION_ID} from OSTYPE, uname -r" {
  OSTYPE='foobar' TEST_UNAME_VERSION='3.27' run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="foobar"' \
    '_GO_PLATFORM_VERSION_ID="3.27"'
}

@test "$SUITE: macos _GO_PLATFORM_{ID,VERSION_ID} from OSTYPE, sw_vers" {
  OSTYPE='darwin16.3.0' TEST_UNAME_VERSION='17.0.0' \
    TEST_MACOS_VERSION='10.13' run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="macos"' \
    '_GO_PLATFORM_VERSION_ID="10.13"'
}

@test "$SUITE: freebsd _GO_PLATFORM_{ID,VERSION_ID} from OSTYPE, uname -r" {
  OSTYPE='freebsd11.0' TEST_UNAME_VERSION='11.1-RELEASE-p1' \
    run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="freebsd"' \
    '_GO_PLATFORM_VERSION_ID="11.1-RELEASE-p1"'
}

@test "$SUITE: msys _GO_PLATFORM_{ID,VERSION_ID} from OSTYPE, uname -r" {
  OSTYPE='msys' TEST_UNAME_VERSION='2.9.0(0.318/5/3)' \
    TEST_GIT_VERSION='2.14.2' run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="msys"' \
    '_GO_PLATFORM_VERSION_ID="2.9.0(0.318/5/3)"'
}

@test "$SUITE: msys-git _GO_PLATFORM_* from OSTYPE, git --version, uname -r" {
  OSTYPE='msys' TEST_UNAME_VERSION='2.8.0(0.310/5/3)' \
    TEST_GIT_VERSION='git version 2.13.0.windows.1' run "$TEST_GO_SCRIPT"
  assert_success
  assert_lines_equal \
    '_GO_PLATFORM_ID="msys-git"' \
    '_GO_PLATFORM_VERSION_ID="2.8.0(0.310/5/3)"'
}
