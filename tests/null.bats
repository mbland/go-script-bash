#! /usr/bin/env bats

load environment

setup() {
  @go.create_test_go_script
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: a good installation emits nothing and exits successfully" {
  COLUMNS=80 run "$TEST_GO_SCRIPT" null
  assert_success ''
}

@test "$SUITE: a bad installation emits errors and exits unsuccessfully" {
  rmdir "$TEST_GO_SCRIPTS_DIR"
  COLUMNS=80 run "$TEST_GO_SCRIPT" null
  assert_failure \
    "ERROR: command script directory $TEST_GO_SCRIPTS_DIR does not exist"
}
