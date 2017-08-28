#! /usr/bin/env bats

load environment

setup() {
  @go.create_test_go_script
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: returns a successful value" {
  COLUMNS=80 run "$TEST_GO_SCRIPT" null
  assert_success ''
}

@test "$SUITE: a bad installation returns a successful value" {
  rmdir "$TEST_GO_SCRIPTS_DIR"
  COLUMNS=80 run "$TEST_GO_SCRIPT" null
  assert_failure \
    "ERROR: command script directory $TEST_GO_SCRIPTS_DIR does not exist"
}
