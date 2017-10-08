#! /usr/bin/env bats

load environment

setup() {
  test_filter
  @go.create_test_go_script '@go "$@"'
  export __GO_ETC_OS_RELEASE="$BATS_TEST_ROOTDIR/os-release"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: emit version information about framework, Bash, and OS" {
  # Use simulated /etc/os-release to prevent computation via uname or sw_vers.
  mkdir -p "$BATS_TEST_ROOTDIR"
  printf '%s\n' \
    'ID=foobar' \
    'VERSION_ID=666' >"$__GO_ETC_OS_RELEASE"

  run "$TEST_GO_SCRIPT" 'goinfo'
  assert_success
  assert_lines_equal \
    "_GO_CORE_VERSION:         $_GO_CORE_VERSION" \
    "BASH_VERSION:             $BASH_VERSION" \
    "OSTYPE:                   $OSTYPE" \
    '_GO_PLATFORM_ID:          foobar' \
    '_GO_PLATFORM_VERSION_ID:  666'
}
