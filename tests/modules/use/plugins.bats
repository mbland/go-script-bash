#! /usr/bin/env bats

load ../../environment

PRINT_SOURCE='printf -- "%s\n" "$BASH_SOURCE"'

setup() {
  test_filter
  @go.create_test_go_script '@go "$@"' \
    'printf "%s\n" "${_GO_IMPORTED_MODULES[@]}"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: plugin imports own internal module" {
  local module_path='foo/bin/lib/foo'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" foo'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'foo/foo'
}

@test "$SUITE: plugin imports own exported module" {
  local module_path='foo/lib/foo'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" foo'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'foo/foo'
}

@test "$SUITE: plugin imports module from own plugin" {
  local module_path='foo/bin/plugins/bar/lib/bar'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar'
}

@test "$SUITE: plugin imports module from other plugin in _GO_PLUGINS_DIR" {
  local module_path='bar/lib/bar'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar'
}

@test "$SUITE: nested plugin imports own internal module" {
  local module_path='foo/bin/plugins/bar/bin/lib/bar-2'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" bar-2'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'bar/bar-2'
}

@test "$SUITE: nested plugin imports own exported module" {
  local module_path='foo/bin/plugins/bar/lib/bar-2'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" bar-2'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'bar/bar-2'
}

@test "$SUITE: nested plugin imports module from own plugin" {
  local module_path='foo/bin/plugins/bar/bin/plugins/baz/lib/baz'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" baz/baz'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'baz/baz'
}

@test "$SUITE: nested plugin imports own module instead of parent module" {
  local module_path='foo/bin/plugins/bar/lib/bar-2'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" bar-2'
  @go.create_test_command_script "plugins/foo/lib/bar-2" "$PRINT_SOURCE"
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'bar/bar-2'
}

@test "$SUITE: nested plugin imports module from parent plugin" {
  local module_path='foo/lib/foo'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" foo/foo'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'foo/foo'
}

@test "$SUITE: nested plugin imports module from _GO_PLUGINS_DIR" {
  local module_path='baz/lib/baz'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" baz/baz'
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'baz/baz'
}

@test "$SUITE: nested plugin imports own module before _GO_PLUGINS_DIR copy" {
  local module_path='foo/bin/plugins/bar/bin/plugins/baz/lib/baz'
  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar'
  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" baz/baz'
  @go.create_test_command_script 'plugins/baz/lib/baz' "$PRINT_SOURCE"
  @go.create_test_command_script "plugins/$module_path" "$PRINT_SOURCE"

  run "$TEST_GO_SCRIPT" 'foo'
  assert_success "$TEST_GO_PLUGINS_DIR/$module_path" 'bar/bar' 'baz/baz'
}

@test "$SUITE: module collision produces warning message, top level first" {
  local top_module_path='baz/lib/baz'
  local nested_module_path='foo/bin/plugins/bar/bin/plugins/baz/lib/baz'

  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" baz/baz'
  @go.create_test_command_script "plugins/$top_module_path" "$PRINT_SOURCE"
  @go.create_test_command_script "plugins/$nested_module_path" "$PRINT_SOURCE"

  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" baz/baz bar/bar'
  run "$TEST_GO_SCRIPT" 'foo'

  local parent_importer="$TEST_GO_PLUGINS_DIR/foo/bin/foo:2"
  local nested_importer="$TEST_GO_PLUGINS_DIR/foo/bin/plugins/bar/lib/bar:2"
  assert_success
  assert_lines_equal "$TEST_GO_PLUGINS_DIR/$top_module_path" \
    'WARNING: Module: baz/baz' \
    "imported at: $nested_importer source" \
    "from file: $TEST_GO_PLUGINS_DIR/$nested_module_path" \
    "previously imported at: $parent_importer source" \
    "from file: $TEST_GO_PLUGINS_DIR/$top_module_path" \
    'baz/baz' \
    'bar/bar'
}

@test "$SUITE: module collision produces warning message, nested level first" {
  local top_module_path='baz/lib/baz'
  local nested_module_path='foo/bin/plugins/bar/bin/plugins/baz/lib/baz'

  @go.create_test_command_script 'plugins/foo/bin/plugins/bar/lib/bar' \
    '. "$_GO_USE_MODULES" baz/baz'
  @go.create_test_command_script "plugins/$top_module_path" "$PRINT_SOURCE"
  @go.create_test_command_script "plugins/$nested_module_path" "$PRINT_SOURCE"

  @go.create_test_command_script 'plugins/foo/bin/foo' \
    '. "$_GO_USE_MODULES" bar/bar baz/baz'
  run "$TEST_GO_SCRIPT" 'foo'

  local parent_importer="$TEST_GO_PLUGINS_DIR/foo/bin/foo:2"
  local nested_importer="$TEST_GO_PLUGINS_DIR/foo/bin/plugins/bar/lib/bar:2"
  assert_success
  assert_lines_equal "$TEST_GO_PLUGINS_DIR/$nested_module_path" \
    'WARNING: Module: baz/baz' \
    "imported at: $parent_importer source" \
    "from file: $TEST_GO_PLUGINS_DIR/$top_module_path" \
    "previously imported at: $nested_importer source" \
    "from file: $TEST_GO_PLUGINS_DIR/$nested_module_path" \
    'bar/bar' \
    'baz/baz'
}
