#! /usr/bin/env bats

load environment
load assertions

setup() {
  . 'lib/command_descriptions'

  declare -g TEST_CMD_SCRIPT="$BATS_TMPDIR/test-command"
  local script='#! /bin/bash
#
# Command that does something in {{root}}
#
# Usage: {{go}} {{cmd}} [args...]
#
# Paragraphs of adjacent lines
# will be joined. They will not be
# folded; @go.printf will take care of
# that.
#
# Lines indented by two spaces
# like the following are considered
# preformatted, and will not be joined:
#
#   foo bar baz
#     preformatted lines should support
#       multiple indentations
#   quux xyzzy plugh
#
# Indented lines that look like tables
# (there are two or more adjacent spaces
# after the first non-space character)
# will be parsed as summary items and folded
# as appropriate. Each table item should be only
# one line long.
#
#   foo    All work and no play makes Mike a dull boy.
#   bar    All Work and no play makes Mike a dull boy.
#   baz    All work and nO play makes Mike a dull boy.
#   quux   All work and no play Makes Mike a dull boy.
#   xyzzy  all work and no play makes mike a Dull Boy.
#   plugh  all werk and no play makes mike a dull Boy

echo The command script starts now.
'
  echo "$script" >"$TEST_CMD_SCRIPT"
}

@test "cmd desc: return default text when no description is available" {
  echo '#! /bin/bash

echo "This script has no description"
' >"$TEST_CMD_SCRIPT"

  local __go_cmd_desc=''
  _@go.command_summary "$TEST_CMD_SCRIPT"
  assert_success
  assert_equal 'No description available' "$__go_cmd_desc" 'command summary'

  __go_cmd_desc=''
  _@go.command_description "$TEST_CMD_SCRIPT"
  assert_success
  assert_equal 'No description available' "$__go_cmd_desc" 'command description'
}

@test "cmd desc: parse summary from command script" {
  _GO_ROOTDIR='/foo/bar'
  _@go.command_summary "$TEST_CMD_SCRIPT"
  assert_success
  assert_equal 'Command that does something in /foo/bar' "$__go_cmd_desc" \
    'command summary'
}

@test "cmd desc: parse description from command script" {
  _GO_CMD='test-go'
  _GO_ROOTDIR='/foo/bar'
  COLUMNS=40
  _@go.command_description "$TEST_CMD_SCRIPT"
  assert_success

  local expected='Command that does something in /foo/bar

Usage: test-go test-command [args...]

Paragraphs of adjacent lines will be joined. They will not be folded; @go.printf will take care of that.

Lines indented by two spaces like the following are considered preformatted, and will not be joined:

  foo bar baz
    preformatted lines should support
      multiple indentations
  quux xyzzy plugh

Indented lines that look like tables (there are two or more adjacent spaces after the first non-space character) will be parsed as summary items and folded as appropriate. Each table item should be only one line long.

  foo    All work and no play makes
           Mike a dull boy.
  bar    All Work and no play makes
           Mike a dull boy.
  baz    All work and nO play makes
           Mike a dull boy.
  quux   All work and no play Makes
           Mike a dull boy.
  xyzzy  all work and no play makes
           mike a Dull Boy.
  plugh  all werk and no play makes
           mike a dull Boy
'

  # With this test, I learned that you _do_ have to quote strings even inside of
  # '[[' and ']]' in case the strings themselves contain '[' or ']', as with
  # '[args...]' above.
  assert_equal "$expected" "$__go_cmd_desc" 'command description'
}

teardown() {
  rm "$TEST_CMD_SCRIPT"
}
