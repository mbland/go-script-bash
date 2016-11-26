#! /usr/bin/env bats

load ../environment

TEST_COMMAND_SCRIPT_PATH="$TEST_GO_SCRIPTS_DIR/test-command"

setup() {
  create_test_go_script '@go "$@"'
  # Though we overwrite the script in most cases, this will also set the
  # permissions so we don't have to do that everywhere.
  create_test_command_script "test-command"
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: run bash script by sourcing" {
  echo '#!/bin/bash' >"$TEST_COMMAND_SCRIPT_PATH"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "$SUITE: run sh script by sourcing" {
  echo '#!/bin/sh' >"$TEST_COMMAND_SCRIPT_PATH"
  echo '@go.printf "%s" "$*"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Can use '@go.printf'
  assert_success 'Can use @go.printf'
}

@test "$SUITE: _GO_* variables are set" {
  local script=(
    '. "$_GO_USE_MODULES" "complete" "format"'
    'local array_decl_pattern="declare -a"'
    'for go_var in "${!_GO_@}"; do'
    '  # Tip from https://stackoverflow.com/questions/14525296/#27254437'
    '  if [[ "$(declare -p "$go_var")" =~ $array_decl_pattern ]]; then'
    '    local arr_ref="$go_var[*]"'
    '    local IFS=,'
    '    echo "$go_var: ${!arr_ref}"'
    '  else'
    '    echo "$go_var: ${!go_var}"'
    '  fi'
    'done')

  local expected=("_GO_CMD: $TEST_GO_SCRIPT"
    "_GO_CMD_ARGV: foo,bar,baz quux,xyzzy"
    "_GO_CMD_NAME: test-command,test-subcommand"
    "_GO_CORE_DIR: $_GO_CORE_DIR"
    "_GO_CORE_URL: $_GO_CORE_URL"
    "_GO_IMPORTED_MODULES: complete,format"
    "_GO_PLUGINS_DIR: "
    "_GO_PLUGINS_PATHS: "
    "_GO_ROOTDIR: $TEST_GO_ROOTDIR"
    "_GO_SCRIPT: $TEST_GO_SCRIPT"
    "_GO_SCRIPTS_DIR: $TEST_GO_SCRIPTS_DIR"
    "_GO_SEARCH_PATHS: $_GO_CORE_DIR/libexec,$TEST_GO_SCRIPTS_DIR"
    "_GO_USE_MODULES: $_GO_CORE_DIR/lib/internal/use")

  create_test_command_script 'test-command.d/test-subcommand' "${script[@]}"
  run "$TEST_GO_SCRIPT" test-command test-subcommand foo bar 'baz quux' xyzzy
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

# Since Bash scripts are sourced, and have access to these variables regardless,
# we use Perl to ensure they are are exported to new processes that run command
# scripts in languages other than Bash.
@test "$SUITE: run perl script; _GO_* variables are exported" {
  if ! command -v perl; then
    skip 'perl not installed'
  fi

  local script=(
    '#!/bin/perl'
    'foreach my $env_var (sort keys %ENV) {'
    '  if ($env_var =~ /^_GO_/) {'
    '    printf("%s: %s\n", $env_var, $ENV{$env_var});'
    '  }'
    '}')

  local expected=("_GO_CMD: $TEST_GO_SCRIPT"
    "_GO_CMD_ARGV: foo"$'\0'"bar"$'\0'"baz quux"$'\0'"xyzzy"
    "_GO_CMD_NAME: test-command"$'\0'"test-subcommand"
    "_GO_CORE_DIR: $_GO_CORE_DIR"
    "_GO_CORE_URL: $_GO_CORE_URL"
    "_GO_ROOTDIR: $TEST_GO_ROOTDIR"
    "_GO_SCRIPT: $TEST_GO_SCRIPT")

  create_test_command_script 'test-command.d/test-subcommand' "${script[@]}"
  run "$TEST_GO_SCRIPT" test-command test-subcommand foo bar 'baz quux' xyzzy
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: produce error if script doesn't contain an interpreter line" {
  if fs_missing_permission_support; then
    # The executable check will fail first because there's no `#!` line.
    skip "Can't trigger condition on this file system"
  fi

  local expected="The first line of $TEST_COMMAND_SCRIPT_PATH does not contain "
  expected+='#!/path/to/interpreter.'

  echo '@go.printf "%s" "$*"' >"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Missing shebang line
  assert_failure "$expected"
}

@test "$SUITE: produce error if shebang line not parseable" {
  local expected='Could not parse interpreter from first line of '
  expected+="$TEST_COMMAND_SCRIPT_PATH."

  echo '#!' >"$TEST_COMMAND_SCRIPT_PATH"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Shebang line not complete
  assert_failure "$expected"
}

@test "$SUITE: parse space after shebang" {
  echo '#! /bin/bash' >"$TEST_COMMAND_SCRIPT_PATH"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Space after shebang OK
  assert_success 'Space after shebang OK'
}

@test "$SUITE: parse /path/to/env bash" {
  echo '#! /path/to/env bash' >"$TEST_COMMAND_SCRIPT_PATH"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command '/path/to/env' OK
  assert_success '/path/to/env OK'
}

@test "$SUITE: ignore flags and arguments after shell name" {
  echo '#!/bin/bash -x' >"$TEST_COMMAND_SCRIPT_PATH"
  echo 'echo "$@"' >>"$TEST_COMMAND_SCRIPT_PATH"

  run "$TEST_GO_SCRIPT" test-command Flags after interpreter ignored
  assert_success 'Flags after interpreter ignored'
}
