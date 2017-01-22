#! /usr/bin/env bats

load ../environment

setup () {
  test_filter
  . 'lib/internal/env/bash'
}

@test "$SUITE: set and unset environment functions" {
  command -v __go_func
  command -v _go_func

  run complete -p _go_func
  assert_success "complete -o nospace -F __go_func _go_func"

  _go_func 'unenv'
  ! command -v __go_func
  ! command -v _go_func
  ! complete -p _go_func
}

@test "$SUITE: environment function forwards commands to script" {
  run _go_func 'help'
  assert_success
  assert_line_equals 0 'Usage: _go_func <command> [arguments...]'
}

@test "$SUITE: environment function handles cd" {
  local orig_pwd="$PWD"

  _go_func 'cd' 'scripts'
  assert_success
  assert_equal "$_GO_ROOTDIR/scripts" "$PWD" 'working dir'

  cd -
  assert_equal "$orig_pwd" "$PWD" 'original working dir'
}

@test "$SUITE: environment function handles pushd" {
  local orig_pwd="$PWD"

  _go_func 'pushd' 'scripts'
  assert_equal "$_GO_ROOTDIR/scripts" "$PWD" 'current working dir'

  popd
  assert_equal "$orig_pwd" "$PWD" 'original working dir'
}

@test "$SUITE: complete first argument lists commands" {
  local COMP_WORDS=('_go_func')
  local COMP_CWORD='1'
  local COMPREPLY=()

  __go_func
  assert_equal 'awk' "${COMPREPLY[0]}" 'first alias'
  assert_equal 'vars' "${COMPREPLY[$((${#COMPREPLY[@]} - 1))]}" 'last builtin'
}

@test "$SUITE: complete second argument" {
  # Complete the flags for the 'commands' builtin.
  local COMP_WORDS=('_go_func' 'commands' '-')
  local COMP_CWORD='2'
  local COMPREPLY=()

  __go_func
  assert_equal '2' "${#COMPREPLY[@]}" 'number of tab completion entries'
  assert_equal '--paths' "${COMPREPLY[0]}" 'first tab completion entry'
  assert_equal '--summaries' "${COMPREPLY[1]}" 'second tab completion entry'
}

@test "$SUITE: complete alias completes filenames in _GO_ROOTDIR" {
  # Complete the '$_GO_ROOTIDR/scripts' directory name.
  local COMP_WORDS=('_go_func' 'ls' 'scrip')
  local COMP_CWORD='2'
  local COMPREPLY=()

  __go_func
  assert_equal '1' "${#COMPREPLY[@]}" 'number of tab completion entries'
  assert_equal 'scripts/' "${COMPREPLY[0]}" 'first tab completion entry'
}
