#! /bin/bash
#
# Common setup for all tests

# Avoid having to fold our test strings. Tests that verify folding behavior will
# override this.
COLUMNS=1000

# Many tests assume the output is generated by running the script directly, so
# we clear the _GO_CMD variable in case the test suite was invoked using a shell
# function.
unset -v _GO_CMD

# Calculate the name of the test suite to make bats output easier to follow.
# This requires that each @test declaration start with "$SUITE: ".
__suite() {
  set +o errexit
  local test_rootdir="$(cd "${BASH_SOURCE[0]%/*}" && echo "$PWD")"
  local relative_filename="${BATS_TEST_FILENAME#$test_rootdir/}"
  echo "${relative_filename%.bats}"
  set -o errexit
}

SUITE="$(__suite)"
