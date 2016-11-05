#! /bin/bash

# Somehow the 'declare' command doesn't work with the bats 'load' command, so
# contrary to the rules in CONTRIBUTING.md, we don't use it here. Also,
# TEST_GO_ROOTDIR contains a space to help ensure that variables are quoted
# properly in most places.
TEST_GO_ROOTDIR="$BATS_TEST_ROOTDIR"
TEST_GO_SCRIPT="$TEST_GO_ROOTDIR/go"
TEST_GO_SCRIPTS_RELATIVE_DIR="scripts"
TEST_GO_SCRIPTS_DIR="$TEST_GO_ROOTDIR/$TEST_GO_SCRIPTS_RELATIVE_DIR"
TEST_GO_PLUGINS_DIR="$TEST_GO_SCRIPTS_DIR/plugins"

create_test_go_script() {
  create_bats_test_script "go" \
    ". '$_GO_ROOTDIR/go-core.bash' '$TEST_GO_SCRIPTS_RELATIVE_DIR'" \
    "$@"

  # Most tests should assume this directory is present. Those that don't should
  # remove it explicitly.
  if [[ ! -d "$TEST_GO_SCRIPTS_DIR" ]]; then
    mkdir "$TEST_GO_SCRIPTS_DIR"
  fi
}

create_test_command_script() {
  create_bats_test_script "$TEST_GO_SCRIPTS_RELATIVE_DIR/$1" "${@:2}"
}

create_core_module_stub() {
  local module_path="$_GO_ROOTDIR/lib/$1"
  shift

  if [[ ! -f "$module_path" ]]; then
    echo "No such core module: $module_path" >&2
    return 1
  fi

  cp "$module_path"{,.stubbed}
  echo '#! /bin/bash' > "$module_path"
  local IFS=$'\n'
  echo "$*" >> "$module_path"
  chmod 600 "$module_path"
}

restore_stubbed_core_modules() {
  local module

  for module in "$_GO_ROOTDIR/lib"/*.stubbed; do
    mv "$module" "${module%.stubbed}"
  done
}

create_parent_and_subcommands() {
  local parent="$1"
  shift
  local subcommand

  create_test_command_script "$parent"

  for subcommand in "$@"; do
    create_test_command_script "$parent.d/$subcommand"
  done
}

remove_test_go_rootdir() {
  remove_bats_test_dirs
}
