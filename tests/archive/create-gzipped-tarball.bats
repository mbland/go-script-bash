#! /usr/bin/env bats

load ../environment

SRC_DIR="$TEST_GO_ROOTDIR/foo"
ITEMS=

setup() {
  test_filter
  @go.create_test_go_script \
    '. "$_GO_USE_MODULES" "archive"' \
    '@go.create_gzipped_tarball "$@"'

  mkdir -p "$SRC_DIR"{/baz,/xyzzy/plugh}
  ITEMS=('bar' 'baz/quux' 'xyzzy/plugh/frobozz' 'xyzzy/plugh/frotz')

  local item
  for item in "${ITEMS[@]}"; do
    printf '%s\n' "$item" >"${SRC_DIR}/${item}"
  done
}

teardown() {
  @go.remove_test_go_rootdir
}

validate_dirs() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  _validate_dirs "$@"
  restore_bats_shell_options "$?"
}

_validate_dirs() {
  local result='0'
  local mirror_dir

  while [[ "$#" -ne '0' ]]; do
    case "$1" in
    --source-kept)
      if [[ ! -d "$SRC_DIR" ]]; then
        printf "Source directory %s should not've been removed\n" "$SRC_DIR" >&2
        result='1'
      fi
      ;;
    --source-removed)
      if [[ -d "$SRC_DIR" ]]; then
        printf "Source directory %s should've been removed\n" "$SRC_DIR" >&2
        result='1'
      fi
      ;;
    --mirror-*)
      if [[ ! "${1#--mirror-}" =~ ^(kept|removed)$ ]]; then
        printf 'Unknown flag: %s\n' "$1" >&2
        result='1'
      elif [[ -z "$2" ]]; then
        printf '%s argument empty\n' "$1" >&2
        result='1'
      fi
      mirror_dir="$TEST_GO_ROOTDIR/$2"

      if [[ "$1" == '--mirror-kept' && ! -d "$mirror_dir" ]]; then
        printf "Mirror directory %s should not've been removed\n" \
          "$mirror_dir" >&2
        result='1'
      elif [[ "$1" == '--mirror-removed' && -d "$mirror_dir" ]]; then
        printf "Mirror directory %s should've been removed\n" "$mirror_dir" >&2
        result='1'
      fi
      shift
      ;;
    *)
      printf 'Unknown flag: %s\n' "$1" >&2
      result='1'
      ;;
    esac
    shift
  done

  rm -rf "$SRC_DIR"
  if [[ -n "$mirror_dir" ]]; then
    rm -rf "$mirror_dir"
  fi
  return "$result"
}

validate_tarball() {
  set "$DISABLE_BATS_SHELL_OPTIONS"
  _validate_tarball "$@"
  restore_bats_shell_options "$?"
}

_validate_tarball() {
  local expected_tarball="$1"
  local expected_items=("${@:2}")
  local __go_collected_file_paths=()
  local unexpected_items=()
  local tarball_name="${expected_tarball##*/}"
  local tarball_dir="${TEST_GO_ROOTDIR}/${tarball_name%.tar.gz}"
  local expected_item
  local actual_item
  local result='0'

  if [[ ! -f "$expected_tarball" ]]; then
    printf 'Did not create expected tarball %s\n' "$expected_tarball" >&2
    result='1'
  elif ! tar -xvzf "$expected_tarball" -C "$TEST_GO_ROOTDIR" >&2; then
    printf 'Failed to extract %s\n' "$expected_tarball" >&2
    result='1'
  else
    for expected_item in "${expected_items[@]}"; do
      if [[ ! -f "$tarball_dir/$expected_item" ]]; then
        printf 'Failed to extract: %s\n' "$expected_item" >&2
        result='1'
      fi
    done

    . "$_GO_USE_MODULES" 'fileutil'
    @go.collect_file_paths "$tarball_dir"
    __go_collected_file_paths=("${__go_collected_file_paths[@]#$tarball_dir/}")

    for actual_item in "${__go_collected_file_paths[@]}"; do
      for expected_item in "${expected_items[@]}"; do
        if [[ "$actual_item" == "$expected_item" ]]; then
          continue 2
        fi
      done
      unexpected_items+=("$actual_item")
    done

    if [[ "${#unexpected_items[@]}" -ne '0' ]]; then
      printf 'Unexpected items included in tarball:\n' >&2
      printf '  %s\n' "${unexpected_items[@]}" >&2
      result='1'
    fi
  fi
  return "$result"
}

@test "$SUITE: successfully create a tarball" {
  skip_if_system_missing 'tar'
  run "$TEST_GO_SCRIPT" "$SRC_DIR"
  assert_success ''
  validate_dirs --source-kept
  validate_tarball "$TEST_GO_ROOTDIR/foo.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: successfully create a tarball relative to PWD" {
  skip_if_system_missing 'tar'

  # _GO_STANDALONE prevents PWD from always being _GO_ROOTDIR.
  cd "$SRC_DIR/xyzzy/plugh"
  _GO_STANDALONE='true' run "$TEST_GO_SCRIPT" '../..'
  cd - >/dev/null

  assert_success ''
  validate_dirs --source-kept
  validate_tarball "$TEST_GO_ROOTDIR/foo.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: successfully create a tarball with a different name" {
  skip_if_system_missing 'tar'
  run "$TEST_GO_SCRIPT" '--name' 'foo-0.1.0' "$SRC_DIR"
  assert_success ''
  validate_dirs --source-kept --mirror-removed 'foo-0.1.0'
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: successfully create a tarball from a symlink" {
  skip_if_system_missing 'tar' 'ln'
  if [[ "$OSTYPE" == 'msys' ]]; then
    skip "ln doesn't work like it normally does on MSYS2"
  fi

  ln -s "$SRC_DIR" "${SRC_DIR}-0.1.0"
  run "$TEST_GO_SCRIPT" '--remove-source' "${SRC_DIR}-0.1.0"
  assert_success ''

  # Remember that `--source-kept` checks `$SRC_DIR`; recursively removing
  # 'foo-0.1.0' should only remove the symlink, but leave `$SRC_DIR` intact.
  validate_dirs --source-kept --mirror-removed 'foo-0.1.0'
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: create a tarball with only certain files" {
  skip_if_system_missing 'tar'
  unset 'ITEMS[0]' 'ITEMS[2]'
  run "$TEST_GO_SCRIPT" '--name' 'foo-0.1.0' "$SRC_DIR" "${ITEMS[@]}"
  assert_success ''
  validate_dirs --source-kept --mirror-removed 'foo-0.1.0'
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: create a tarball from a symlink with only certain files" {
  skip_if_system_missing 'tar' 'ln'
  if [[ "$OSTYPE" == 'msys' ]]; then
    skip "ln doesn't work like it normally does on MSYS2"
  fi

  ln -s "$SRC_DIR" "${SRC_DIR}-0.1.0"
  unset 'ITEMS[0]' 'ITEMS[2]'
  run "$TEST_GO_SCRIPT" "${SRC_DIR}-0.1.0" "${ITEMS[@]}"
  assert_success ''
  validate_dirs --source-kept --mirror-kept 'foo-0.1.0'
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: remove the source directory after creating the tarball" {
  skip_if_system_missing 'tar'
  run "$TEST_GO_SCRIPT" '--name' 'foo-0.1.0' '--remove-source' "$SRC_DIR"
  assert_success ''
  validate_dirs --source-removed
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: keep the mirror directory after creating the tarball" {
  skip_if_system_missing 'tar'
  run "$TEST_GO_SCRIPT" '--name' 'foo-0.1.0' '--keep-mirror' "$SRC_DIR"
  assert_success ''
  validate_dirs --source-kept --mirror-kept 'foo-0.1.0'
  validate_tarball "$TEST_GO_ROOTDIR/foo-0.1.0.tar.gz" "${ITEMS[@]}"
}

@test "$SUITE: logs FATAL when the source directory doesn't exist" {
  run "$TEST_GO_SCRIPT" "$TEST_GO_ROOTDIR/nonexistent"
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Source directory $TEST_GO_ROOTDIR/nonexistent doesn't exist"
}

@test "$SUITE: logs FATAL when tar fails" {
  skip_if_system_missing 'tar'
  stub_program_in_path 'tar' \
    'if [[ "$1" == '-czf' ]]; then' \
    '  exit 1' \
    'fi' \
    "$(command -v 'tar') \"\$@\""

  run "$TEST_GO_SCRIPT" "$SRC_DIR"
  restore_program_in_path 'tar'
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Failed to create $SRC_DIR.tar.gz from $SRC_DIR"
}

@test "$SUITE: logs fatal when removing the mirror dir fails" {
  skip_if_system_missing 'tar'

  local tarball_dir="${SRC_DIR}-0.1.0"

  stub_program_in_path 'rm' \
    "if [[ \"\$2\" ==  \"$tarball_dir\" ]]; then" \
    '  exit 1' \
    'fi' \
    "$(command -v 'rm') \"\$@\""

  run "$TEST_GO_SCRIPT" '--name' 'foo-0.1.0' "$SRC_DIR"
  restore_program_in_path 'rm'
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Failed to remove $tarball_dir after creating ${tarball_dir}.tar.gz"
}

@test "$SUITE: logs fatal when removing the source dir fails" {
  skip_if_system_missing 'tar'

  stub_program_in_path 'rm' \
    "if [[ \"\$2\" ==  \"${SRC_DIR}\" ]]; then" \
    '  exit 1' \
    'fi' \
    "$(command -v 'rm') \"\$@\""

  run "$TEST_GO_SCRIPT" '--remove-source' "$SRC_DIR"
  restore_program_in_path 'rm'
  assert_failure
  assert_line_matches '0' \
    "FATAL.* Failed to remove $SRC_DIR after creating ${SRC_DIR}.tar.gz"
}
