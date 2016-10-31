#! /usr/bin/env bats

load ../environment
load ../assertions

. "$_GO_ROOTDIR/lib/complete"

@test "$SUITE: empty args, empty completions" {
  local argv=()
  local completions=()
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal '' "${completions[*]}"
}

@test "$SUITE: empty args, single completion" {
  local argv=()
  local completions=('foo')
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal 'foo' "${completions[*]}"
}

@test "$SUITE: single arg, no completions" {
  local argv=('foo')
  local completions=()
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal '' "${completions[*]}"
}

@test "$SUITE: single arg remove single matching completion" {
  local argv=('foo')
  local completions=('foo')
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal '' "${completions[*]}"
}

@test "$SUITE: single arg, two completions, remove match" {
  local argv=('foo/bar')
  local completions=('foo/bar' 'foo/baz')
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal 'foo/baz' "${completions[*]}"
}

@test "$SUITE: two args, twos completions, remove both" {
  local argv=('foo/bar' 'foo/baz')
  local completions=('foo/bar' 'foo/baz')
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"
  assert_equal '' "${completions[*]}"
}

@test "$SUITE: several args, several completions" {
  local argv=('foo/bar' 'baz/quux' 'xyzzy/plugh' 'frotz/frobozz')
  local completions=('foo/bar' 'foo/baz' 'foo/quux' 
    'frotz' 'frotz/blorple' 'frotz/frobozz')
  @go.complete_remove_completions_already_present \
    'argv' 'completions' "${#completions[@]}"

  local expected=('foo/baz' 'foo/quux' 'frotz' 'frotz/blorple')
  local IFS=$'\n'
  assert_equal "${expected[*]}" "${completions[*]}"
}
