#! /bin/bash

# Somehow the 'declare' command doesn't work with the bats 'load' command, so
# contrary to the rules in CONTRIBUTING.md, we don't use it here. Also,
# TEST_GO_ROOTDIR contains a space to help ensure that variables are quoted
# properly in most places.
TEST_GO_ROOTDIR="$BATS_TMPDIR/test rootdir"
TEST_GO_SCRIPT="$TEST_GO_ROOTDIR/go"
TEST_GO_SCRIPTS_RELATIVE_DIR="scripts"
TEST_GO_SCRIPTS_DIR="$TEST_GO_ROOTDIR/$TEST_GO_SCRIPTS_RELATIVE_DIR"
TEST_COMMAND_SCRIPT="$TEST_GO_SCRIPTS_DIR/test-command"

__create_test_dirs() {
  local test_dir

  for test_dir in "$TEST_GO_ROOTDIR" "$TEST_GO_SCRIPTS_DIR"; do
    if [[ ! -d "$test_dir" ]]; then
      mkdir "$test_dir"
    fi
  done
}

__create_test_script() {
  local script="$1"
  shift
  local line

  __create_test_dirs
  echo "#! $BASH" >"$script"

  for line in "$@"; do
    echo "$line" >>"$script"
  done
  chmod 700 "$script"
}

create_test_go_script() {
  __create_test_script "$TEST_GO_SCRIPT" \
    ". '$_GO_ROOTDIR/go-core.bash' '$TEST_GO_SCRIPTS_RELATIVE_DIR'" \
    "$@"
}

create_test_command_script() {
  __create_test_script "$TEST_COMMAND_SCRIPT" \
    "$@"
}

remove_test_go_rootdir() {
  chmod -R u+rwx "$TEST_GO_ROOTDIR"
  rm -rf "$TEST_GO_ROOTDIR"
}
