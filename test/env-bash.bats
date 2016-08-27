#! /usr/bin/env bats

load environment
load assertions

setup () {
  . 'lib/env/bash'
}

@test "env-bash: set and unset environment functions" {
  command -v __go_func
  command -v _go_func

  run complete -p _go_func
  assert_success "complete -o filenames -F __go_func _go_func"

  _go_func 'unenv'
  ! command -v __go_func
  ! command -v _go_func
  ! complete -p _go_func
}

@test "env-bash: environment function forwards commands to script" {
  . 'lib/env/bash'

  run _go_func 'help'
  assert_success
  assert_line_equals 0 'Usage: _go_func <command> [arguments...]'
}

@test "env-bash: environment function handles cd" {
  local orig_pwd="$PWD"

  _go_func 'cd' 'scripts'
  assert_success
  assert_equal "$_GO_ROOTDIR/scripts" "$PWD" 'working dir'

  cd -
  assert_equal "$orig_pwd" "$PWD" 'original working dir'
}

@test "env-bash: environment function handles pushd" {
  local orig_pwd="$PWD"

  _go_func 'pushd' 'scripts'
  assert_equal "$_GO_ROOTDIR/scripts" "$PWD" 'current working dir'

  popd
  assert_equal "$orig_pwd" "$PWD" 'original working dir'
}

@test "env-bash: tab complete first argument lists commands, keeps PWD" {
  local COMP_WORDS=('_go_func')
  local COMP_CWORD='1'
  local COMP_LINE='_go_func'
  local COMP_POINT="${#COMP_LINE}"
  local COMPREPLY

  cd 'scripts'
  __go_func
  assert_success
  assert_equal 'awk' "${COMPREPLY[0]}" 'first alias'
  assert_equal 'unenv' "${COMPREPLY[$((${#COMPREPLY[@]} - 1))]}" 'last builtin'
  assert_equal "$_GO_ROOTDIR/scripts" "$PWD" 'current working dir'
  cd -
}

@test "env-bash: tab complete second argument, changes dir to _GO_ROOTDIR" {
  # Complete the flags for the 'commands' builtin.
  local COMP_WORDS=('_go_func' 'commands' '-')
  local COMP_CWORD='2'
  local COMP_LINE='_go_func commands -'
  local COMP_POINT="${#COMP_LINE}"
  local COMPREPLY

  cd 'scripts'
  __go_func
  assert_success
  assert_equal '2' "${#COMPREPLY[@]}" 'number of tab completion entries'
  assert_equal '--summaries' "${COMPREPLY[0]}" 'first tab completion entry'
  assert_equal '--paths' "${COMPREPLY[1]}" 'second tab completion entry'

  assert_equal "$_GO_ROOTDIR" "$PWD" 'current working dir'
  cd -
}

@test "env-bash: tab complete alias completes filenames in _GO_ROOTDIR" {
  # Complete the '$_GO_ROOTIDR/scripts' directory name.
  local COMP_WORDS=('_go_func' 'ls' 'scrip')
  local COMP_CWORD='2'
  local COMP_LINE='_go_func ls script'
  local COMP_POINT="${#COMP_LINE}"
  local COMPREPLY

  cd 'scripts'
  __go_func
  assert_success
  assert_equal '1' "${#COMPREPLY[@]}" 'number of tab completion entries'
  assert_equal 'scripts' "${COMPREPLY[0]}" 'first tab completion entry'

  assert_equal "$_GO_ROOTDIR" "$PWD" 'current working dir'
  cd -
}
