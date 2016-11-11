#! /usr/bin/env bats

load environment

@test "$SUITE: open file with EDITOR" {
  run env EDITOR='echo' ./go edit foo/bar/baz
  assert_success 'foo/bar/baz'
}

@test "$SUITE: error if EDITOR not defined" {
  run env EDITOR= ./go edit foo/bar/baz
  assert_failure 'Cannot edit foo/bar/baz: $EDITOR not defined.'
}
