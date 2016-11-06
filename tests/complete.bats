#! /usr/bin/env bats

load environment
load commands/helpers

setup() {
  create_test_go_script '@go "$@"'
  find_builtins
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: complete help flag variations" {
  run "$TEST_GO_SCRIPT" complete 0 -h
  assert_success '-h'

  run "$TEST_GO_SCRIPT" complete 0 -he
  assert_success '-help'

  run "$TEST_GO_SCRIPT" complete 0 -
  assert_success '--help'

  run "$TEST_GO_SCRIPT" complete 0 --
  assert_success '--help'
}

@test "$SUITE: all top-level commands for zeroth or first argument" {
  # Aliases will get printed before all other commands.
  local __all_commands=("$(./go 'aliases')" "${BUILTIN_CMDS[@]}")

  run "$TEST_GO_SCRIPT" complete 0
  local IFS=$'\n'
  assert_success "${__all_commands[*]}"

  run "$TEST_GO_SCRIPT" complete 0 complete
  assert_success 'complete'

  run "$TEST_GO_SCRIPT" complete 0 complete-not
  assert_failure ''
}

@test "$SUITE: cd and pushd complete directories" {
  local subdirs=('bar' 'baz' 'foo')
  local files=('plugh' 'quux' 'xyzzy')
  mkdir -p "${subdirs[@]/#/$TEST_GO_SCRIPTS_DIR/}"
  touch "${files[@]/#/$TEST_GO_SCRIPTS_DIR/}"

  run "$TEST_GO_SCRIPT" complete 1 cd ''
  assert_success 'scripts'
  run "$TEST_GO_SCRIPT" complete 1 pushd ''
  assert_success 'scripts'

  local prev_IFS="$IFS"
  local IFS=$'\n'
  local expected=($(compgen -d "$TEST_GO_SCRIPTS_DIR/"))
  IFS="$prev_IFS"
  expected=("${expected[@]#$TEST_GO_ROOTDIR/}")

  run "$TEST_GO_SCRIPT" complete 1 cd 'scripts/'
  IFS=$'\n'
  assert_success "${expected[*]}"
  run "$TEST_GO_SCRIPT" complete 1 pushd 'scripts/'
  assert_success "${expected[*]}"
}

@test "$SUITE: edit, run, and aliases complete directories and files" {
  local subdirs=('bar' 'baz' 'foo')
  local files=('plugh' 'quux' 'xyzzy')
  mkdir -p "${subdirs[@]/#/$TEST_GO_SCRIPTS_DIR/}"
  touch "${files[@]/#/$TEST_GO_SCRIPTS_DIR/}"

  local prevIFS="$IFS"
  local IFS=$'\n'
  local top_level=($(compgen -f "$TEST_GO_ROOTDIR/"))
  local all_scripts_entries=($(compgen -f "$TEST_GO_SCRIPTS_DIR/"))
  IFS="$prevIFS"
  top_level=("${top_level[@]#$TEST_GO_ROOTDIR/}")
  all_scripts_entries=("${all_scripts_entries[@]#$TEST_GO_ROOTDIR/}")

  run "$TEST_GO_SCRIPT" complete 1 edit ''
  local IFS=$'\n'
  assert_success "${top_level[*]}"
  run "$TEST_GO_SCRIPT" complete 1 run ''
  assert_success "${top_level[*]}"
  run "$TEST_GO_SCRIPT" complete 1 ls ''
  assert_success "${top_level[*]}"

  run "$TEST_GO_SCRIPT" complete 1 edit 'scripts/'
  assert_success "${all_scripts_entries[*]}"
  run "$TEST_GO_SCRIPT" complete 1 run 'scripts/'
  assert_success "${all_scripts_entries[*]}"
  run "$TEST_GO_SCRIPT" complete 1 ls 'scripts/'
  assert_success "${all_scripts_entries[*]}"
}

@test "$SUITE: unenv, unknown flags, and unknown commands return errors" {
  run "$TEST_GO_SCRIPT" complete 1 unenv ''
  assert_failure ''

  run "$TEST_GO_SCRIPT" complete 1 --foobar ''
  assert_failure ''

  run "$TEST_GO_SCRIPT" complete 1 foobar ''
  assert_failure ''
}

@test "$SUITE: invoke command script completion" {
  create_test_command_script foo \
    'if [[ "$1" == "--complete" ]]; then ' \
    '  # Tab completions' \
    '  local index="$2"' \
    '  shift; shift' \
    '  local args=("$@")' \
    '  compgen -W "bar baz quux" -- "${args[$index]}"' \
    'fi'

  run "$TEST_GO_SCRIPT" complete 0 foo
  assert_success 'foo'

  local expected=('bar' 'baz' 'quux')
  local IFS=$'\n'
  run "$TEST_GO_SCRIPT" complete 1 foo ''
  assert_success "${expected[*]}"

  expected=('bar' 'baz')
  run "$TEST_GO_SCRIPT" complete 1 foo 'b'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" complete 2 foo 'b' 'q'
  assert_success 'quux'

  run "$TEST_GO_SCRIPT" complete 1 foo 'x'
  assert_failure ''
}

@test "$SUITE: command script completion not detected without comment" {
  create_test_command_script foo \
    'if [[ "$1" == "--complete" ]]; then ' \
    '  local index="$2"' \
    '  shift; shift' \
    '  local args=("$@")' \
    '  compgen -W "bar baz quux" -- "${args[$index]}"' \
    'fi'

  run "$TEST_GO_SCRIPT" complete 0 foo
  assert_success 'foo'

  run "$TEST_GO_SCRIPT" complete 1 foo ''
  assert_failure ''
}

@test "$SUITE: subcommand script completion" {
  create_test_command_script foo \
    'if [[ "$1" == "--complete" ]]; then ' \
    '  # Tab completions' \
    '  local index="$2"' \
    '  shift; shift' \
    '  local args=("$@")' \
    '  compgen -W "baz quux" -- "${args[$index]}"' \
    'fi'

  mkdir "$TEST_GO_SCRIPTS_DIR/foo.d"

  create_test_command_script foo.d/bar \
    'if [[ "$1" == "--complete" ]]; then ' \
    '  # Tab completions' \
    '  local index="$2"' \
    '  shift; shift' \
    '  local args=("$@")' \
    '  compgen -W "plugh xyzzy" -- "${args[$index]}"' \
    'fi'

  run "$TEST_GO_SCRIPT" complete 0 foo
  assert_success 'foo'

  # Note that 'bar' should show up automatically because it is in foo.d, even
  # though it isn't in the compgen word list inside foo.
  local expected=('bar' 'baz' 'quux')
  local IFS=$'\n'
  run "$TEST_GO_SCRIPT" complete 1 foo ''
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" complete 1 foo bar
  assert_success 'bar'

  local expected=('plugh' 'xyzzy')
  run "$TEST_GO_SCRIPT" complete 2 foo bar ''
  assert_success "${expected[*]}"
}

@test "$SUITE: -h, -help, and --help invoke help command completion" {
  run "$TEST_GO_SCRIPT" complete 1 -h 'complet'
  assert_success 'complete'

  run "$TEST_GO_SCRIPT" complete 1 -help 'complet'
  assert_success 'complete'

  run "$TEST_GO_SCRIPT" complete 1 --help 'complet'
  assert_success 'complete'
}
