#! /usr/bin/env bats

load environment
load assertions
load script_helper

setup() {
  create_test_go_script '@go "$@"'
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: tab completion" {
  run "$TEST_GO_SCRIPT" plugins --complete 0 ''
  assert_failure ''

  local plugins_dir="$TEST_GO_SCRIPTS_DIR/plugins"
  mkdir "$plugins_dir"
  create_test_command_script "plugins/foo"

  run "$TEST_GO_SCRIPT" plugins --complete 0 ''
  local expected=('--paths' '--summaries')
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" plugins --complete 0 '--paths'
  assert_success '--paths'
}

@test "$SUITE: error if no scripts/plugin directory" {
  run "$TEST_GO_SCRIPT" plugins
  assert_failure ''
}

@test "$SUITE: error if no plugins present" {
  local plugins_dir="$TEST_GO_SCRIPTS_DIR/plugins"
  mkdir "$plugins_dir"

  run "$TEST_GO_SCRIPT" plugins
  assert_failure ''
}

@test "$SUITE: show plugin info" {
  local plugins_dir="$TEST_GO_SCRIPTS_DIR/plugins"
  mkdir -p "$plugins_dir/bar/bin" "$plugins_dir/plugh/bin"

  local plugins=(
    'plugins/bar/bin/bar'
    'plugins/bar/bin/baz'
    'plugins/foo'
    'plugins/plugh/bin/plugh'
    'plugins/xyzzy')
  local plugin
  local longest_plugin_len=0
  local plugin_path
  local summary
  local IFS=$'\n'

  for plugin in "${plugins[@]}"; do
    create_test_command_script "$plugin"
    summary="Does ${plugin##*/} stuff"
    echo "# $summary" >> "$TEST_GO_SCRIPTS_DIR/$plugin"

    plugin="${plugin##*/}"
    if [[ "$longest_plugin_len" -lt "${#plugin}" ]]; then
      longest_plugin_len="${#plugin}"
    fi
  done

  run "$TEST_GO_SCRIPT" plugins
  assert_success "${plugins[*]##*/}"

  local paths=(
    'bar    scripts/plugins/bar/bin/bar'
    'baz    scripts/plugins/bar/bin/baz'
    'foo    scripts/plugins/foo'
    'plugh  scripts/plugins/plugh/bin/plugh'
    'xyzzy  scripts/plugins/xyzzy')

  run "$TEST_GO_SCRIPT" plugins --paths
  assert_success "${paths[*]}"

  local summaries=(
    '  bar    Does bar stuff'
    '  baz    Does baz stuff'
    '  foo    Does foo stuff'
    '  plugh  Does plugh stuff'
    '  xyzzy  Does xyzzy stuff')

  run "$TEST_GO_SCRIPT" plugins --summaries
  assert_success "${summaries[*]}"
}
