#! /usr/bin/env bats

load environment

setup() {
  . 'lib/format'
}

@test "$SUITE: does nothing for empty argv" {
  local items=()
  local __go_padded_result=()
  @go.pad_items 'items'
  assert_equal '' "${__go_padded_result[*]}"
}

@test "$SUITE: pads argv items" {
  local items=('foo' 'bar' 'baz' 'xyzzy' 'quux')
  local __go_padded_result=()
  @go.pad_items 'items'

  local IFS='|'
  assert_equal 'foo  |bar  |baz  |xyzzy|quux ' "${__go_padded_result[*]}"
}

@test "$SUITE: zip empty items" {
  local lhs=()
  local rhs=()
  local __go_zipped_result=()
  @go.zip_items 'lhs' 'rhs' '='

  assert_equal '' "${__go_zipped_result[*]}"
}

@test "$SUITE: zip matching items" {
  local lhs=('foo' 'xyzzy' 'quux')
  local rhs=('bar' 'baz' 'plugh')
  local __go_zipped_result=()
  @go.zip_items 'lhs' 'rhs' '='

  local expected=('foo=bar' 'xyzzy=baz' 'quux=plugh')
  local IFS=$'\n'
  local indent='    '
  assert_equal $'\n'"${expected[*]/#/$indent}" \
    $'\n'"${__go_zipped_result[*]/#/$indent}"
}
