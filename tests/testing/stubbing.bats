#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/testing/stubbing"

setup() {
  test_filter
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: create_core_module_stub and restore_stubbed_core_modules" {
  [ -e "$_GO_CORE_DIR/lib/log" ]
  [ ! -e "$_GO_CORE_DIR/lib/log.stubbed" ]
  create_core_module_stub 'log' 'echo Hello, World!'
  [ -e "$_GO_CORE_DIR/lib/log.stubbed" ]
  [ -e "$_GO_CORE_DIR/lib/log" ]

  create_test_go_script '. "$_GO_USE_MODULES" log'
  run "$TEST_GO_SCRIPT"

  restore_stubbed_core_modules
  [ ! -e "$_GO_CORE_DIR/lib/log.stubbed" ]
  [ -e "$_GO_CORE_DIR/lib/log" ]
  assert_success 'Hello, World!'
}
