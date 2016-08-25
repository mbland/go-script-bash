#! /usr/bin/env bats

setup () {
  . 'lib/env/bash'
}

@test "env-bash: set and unset environment functions" {
  command -v __go_func
  command -v _go_func

  run complete -p _go_func
  [[ "$status" -eq '0' ]]
  [[ "$output" = "complete -o filenames -F __go_func _go_func" ]]

  _go_func 'unenv'
  ! command -v __go_func
  ! command -v _go_func
  ! complete -p _go_func
}

@test "env-bash: environment function forwards commands to script" {
  . 'lib/env/bash'

  run _go_func 'help'
  [[ "$status" -eq '0' ]]
  [[ "${lines[0]}" = 'Usage: _go_func <command> [arguments...]' ]]
}

@test "env-bash: environment function handles cd" {
  local orig_pwd="$PWD"

  _go_func 'cd' 'scripts'
  [[ "$PWD" = "$_GO_ROOTDIR/scripts" ]]

  cd -
  [[ "$PWD" = "$orig_pwd" ]]
}

@test "env-bash: environment function handles pushd" {
  local orig_pwd="$PWD"

  _go_func 'pushd' 'scripts'
  [[ "$PWD" = "$_GO_ROOTDIR/scripts" ]]

  popd
  [[ "$PWD" = "$orig_pwd" ]]
}

@test "env-bash: tab complete first argument lists commands, keeps PWD" {
  local COMP_WORDS=('_go_func')
  local COMP_CWORD='1'
  local COMP_LINE='_go_func'
  local COMP_POINT="${#COMP_LINE}"
  local COMPREPLY

  cd 'scripts'
  __go_func
  [[ "$status" -eq '0' ]]
  [[ "${COMPREPLY[0]}" = 'awk' ]]  # First alias
  [[ "${COMPREPLY[$((${#COMPREPLY[@]} - 1))]}" = 'unenv' ]]  # Last builtin

  [[ "$PWD" = "$_GO_ROOTDIR/scripts" ]]
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
  [[ "$status" -eq '0' ]]
  [[ "${#COMPREPLY[@]}" -eq '2' ]]
  [[ "${COMPREPLY[0]}" = '--summaries' ]]
  [[ "${COMPREPLY[1]}" = '--paths' ]]

  [[ "$PWD" = "$_GO_ROOTDIR" ]]
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
  [[ "$status" -eq '0' ]]
  [[ "${#COMPREPLY[@]}" -eq '1' ]]
  [[ "${COMPREPLY[0]}" = 'scripts' ]]

  [[ "$PWD" = "$_GO_ROOTDIR" ]]
  cd -
}
