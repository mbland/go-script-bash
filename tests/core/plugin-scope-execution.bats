#! /usr/bin/env bats

load ../environment

PRINT_SOURCE='printf -- "%s\n" "$BASH_SOURCE"'

setup() {
  test_filter
  @go.create_test_go_script '@go "$@"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: project script takes precedence over plugin" {
  @go.create_test_command_script 'plugins/foo/bin/foo' "$PRINT_SOURCE"
  @go.create_test_command_script 'foo' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/foo"
}

@test "$SUITE: plugin can't use script from top-level _GO_SCRIPTS_DIR" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'bar' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_failure
  assert_line_equals 0 'Unknown command: bar'
}

@test "$SUITE: plugin can use script from top-level _GO_PLUGINS_DIR" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/bar/bin/bar' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/bar/bin/bar"
}

@test "$SUITE: plugin can use plugin from own plugin dir" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' \
    "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/plugins/bar/bin/bar"
}

@test "$SUITE: plugin's local _GO_SCRIPTS_DIR scripts take precedence" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/bar' "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/bar/bin/bar' "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' \
    "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/bar"
}

@test "$SUITE: local plugins take precedence over top-level _GO_PLUGINS_DIR" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/bar/bin/bar' "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' \
    "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/plugins/bar/bin/bar"
}

@test "$SUITE: circular dependencies in nested plugin dirs" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/baz' "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' '@go baz'

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/baz"
}

@test "$SUITE: circular dependencies in top-level _GO_PLUGINS_DIR" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/baz' "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/bar/bin/bar' '@go baz'

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/baz"
}

@test "$SUITE: nested plugin's _GO_SCRIPTS_DIR precedes plugins" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' '@go baz'

  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script \
    'plugins/foo/bin/plugins/bar/bin/plugins/baz/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/foo/bin/plugins/baz/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/baz/bin/baz' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/plugins/bar/bin/baz"
}

@test "$SUITE: nested plugin's plugins precede parents' plugins" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' '@go baz'

  @go.create_test_command_script \
    'plugins/foo/bin/plugins/bar/bin/plugins/baz/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/foo/bin/plugins/baz/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/baz/bin/baz' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success \
    "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/plugins/bar/bin/plugins/baz/bin/baz"
}

@test "$SUITE: nested plugin's sibling precedes top-level _GO_PLUGINS_DIR" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' '@go baz'

  @go.create_test_command_script 'plugins/foo/bin/plugins/baz/bin/baz' \
    "$PRINT_SOURCE"
  @go.create_test_command_script 'plugins/baz/bin/baz' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/foo/bin/plugins/baz/bin/baz"
}

@test "$SUITE: nested plugin finds top-level _GO_PLUGINS_DIR plugin" {
  @go.create_test_command_script 'plugins/foo/bin/foo' '@go bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/bin/bar' '@go baz'

  @go.create_test_command_script 'plugins/baz/bin/baz' "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_SCRIPTS_DIR/plugins/baz/bin/baz"
}
