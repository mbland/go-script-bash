#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/portability"

@test "$SUITE: return unaltered path if _GO_PLATFORM_ID isn't msys-git" {
  local result
  _GO_PLATFORM_ID='foobar' @go.native_file_path_or_url 'result' '/foo/bar'
  assert_equal '/foo/bar' "$result"
}

@test "$SUITE: return unaltered path if protocol isn't file://" {
  local result
  _GO_PLATFORM_ID='msys-git' \
    @go.native_file_path_or_url 'result' 'https://mike-bland.com/'
  assert_equal 'https://mike-bland.com/' "$result"
}

@test "$SUITE: return updated file system path" {
  skip_if_system_missing 'cygpath'
  local result
  _GO_PLATFORM_ID='msys-git' @go.native_file_path_or_url 'result' '/foo/bar'
  assert_equal "$(cygpath -m '/foo/bar')" "$result"
}

@test "$SUITE: return updated file:// URL" {
  skip_if_system_missing 'cygpath'
  local result
  _GO_PLATFORM_ID='msys-git' \
    @go.native_file_path_or_url 'result' 'file:///foo/bar'
  assert_equal "file://$(cygpath -m '/foo/bar')" "$result"
}
