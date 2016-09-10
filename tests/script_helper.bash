#! /bin/bash

# Somehow the 'declare' command doesn't work with the bats 'load' command, so
# contrary to the rules in CONTRIBUTING.md, we don't use it here. Also,
# TEST_GO_ROOTDIR contains a space to help ensure that variables are quoted
# properly in most places.
TEST_GO_ROOTDIR="$BATS_TMPDIR/test rootdir"
TEST_GO_SCRIPT="$TEST_GO_ROOTDIR/go"
TEST_GO_SCRIPTS_RELATIVE_DIR="scripts"
TEST_GO_SCRIPTS_DIR="$TEST_GO_ROOTDIR/$TEST_GO_SCRIPTS_RELATIVE_DIR"

# The FS_MISSING_PERM_SUPPORT variable provides a generic means of determining
# whether or not to skip certain tests, since the lack of permission support
# prevents some code paths from ever getting executed.
#
# MINGW64- and MSYS2-based file systems are mounted with the 'noacl'
# attribute, which prevents chmod from having any effect. These file systems
# do automatically mark files beginning with '#!' as executable, however,
# which is why several tests create files containing only those characters.
#
# Also, directories on these file systems are always readable and executable.
#
# See commit 2794086bde1dc05193154211fe0577728031453c for more details.
fs_missing_permission_support() {
  if [[ -z "$FS_MISSING_PERMISSION_SUPPORT" ]]; then
    local check_perms_file="$BATS_TMPDIR/check_perms"
    touch "$check_perms_file"
    chmod 700 "$check_perms_file"
    if [[ ! -x "$check_perms_file" ]]; then
      export FS_MISSING_PERMISSION_SUPPORT="true"
    else
      export FS_MISSING_PERMISSION_SUPPORT="false"
    fi
    rm "$check_perms_file"
  fi

  [[ "$FS_MISSING_PERMISSION_SUPPORT" == 'true' ]]
}

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
  echo "#! /usr/bin/env bash" >"$script"

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
  local script_path="$TEST_GO_SCRIPTS_DIR/$1"
  shift
  __create_test_script "$script_path" "$@"
}

create_parent_and_subcommands() {
  local parent="$1"
  shift
  create_test_command_script "$parent"

  local subcommand
  mkdir "$TEST_GO_SCRIPTS_DIR/$parent.d"

  for subcommand in "$@"; do
    create_test_command_script "$parent.d/$subcommand"
  done
}

remove_test_go_rootdir() {
  chmod -R u+rwx "$TEST_GO_ROOTDIR"
  rm -rf "$TEST_GO_ROOTDIR"
}
