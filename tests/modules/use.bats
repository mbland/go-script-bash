#! /usr/bin/env bats

load ../environment
load "$_GO_CORE_DIR/lib/testing/stubbing"

TEST_MODULES=(
  "$_GO_CORE_DIR/lib/builtin-test"
  "$TEST_GO_PLUGINS_DIR/test-plugin/lib/plugin-test"
  "$TEST_GO_ROOTDIR/lib/export-test"
  "$TEST_GO_SCRIPTS_DIR/lib/internal-test"
)
IMPORTS=('test-plugin/plugin-test' 'internal-test' 'builtin-test' 'export-test')
EXPECTED=(
  "plugin-test loaded"
  "internal-test loaded"
  "builtin-test loaded"
  "export-test loaded"
  "modules: ${IMPORTS[*]}"
)

setup() {
  test_filter

  local core_test_module
  for core_test_module in 'builtin-test' 'go-use-modules-test'; do
    if [[ -e "$_GO_CORE_DIR/lib/$core_test_module" ]]; then
      printf 'ERROR: "%s" exists, aborting.\n' "$core_test_module" >&2
      return 1
    fi
  done

  @go.create_test_go_script \
    ". \"\$_GO_USE_MODULES\" $*" \
    'echo modules: "${_GO_IMPORTED_MODULES[*]}"'

  local module
  for module in "${TEST_MODULES[@]}"; do
    mkdir -p "${module%/*}"
    echo "echo '${module##*/}' loaded" > "$module"
  done
}

teardown() {
  rm -rf "$_GO_CORE_DIR/lib/"{builtin-test,go-use-modules-test}
  @go.remove_test_go_rootdir
}

@test "$SUITE: no modules imported by default" {
  @go.create_test_go_script 'echo modules: "${_GO_IMPORTED_MODULES[*]}"'
  run "$TEST_GO_SCRIPT"
  assert_success 'modules: '
}

@test "$SUITE: does nothing if no modules specified" {
  run "$TEST_GO_SCRIPT"
  assert_success 'modules: '
}

@test "$SUITE: error if nonexistent module specified" {
  run "$TEST_GO_SCRIPT" 'bogus-test-module'

  local expected=('ERROR: Module bogus-test-module not found at:'
    "  $TEST_GO_SCRIPT:3 main")
  assert_failure "${expected[@]}"
}

@test "$SUITE: import modules successfully" {
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"
  assert_success "${EXPECTED[@]}"
}

@test "$SUITE: import each module only once" {
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}" "${IMPORTS[@]}" "${IMPORTS[@]}"
  assert_success "${EXPECTED[@]}"
}

@test "$SUITE: prevent self, circular, and multiple importing" {
  local module

  for module in "${TEST_MODULES[@]}"; do
    echo ". \"\$_GO_USE_MODULES\" ${IMPORTS[@]}" >> "$module"
  done

  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"
  assert_success "${EXPECTED[@]}"
}

@test "$SUITE: error if module contains errors" {
  # These correspond to the 'internal-test' module.
  local module="${IMPORTS[1]}"
  local module_file="${TEST_MODULES[3]}"

  echo "This is a totally broken module." > "$module_file"
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"

  local expected=("${IMPORTS[0]##*/} loaded"
    "$module_file: line 1: This: command not found"
    "ERROR: Failed to import $module module from $module_file at:"
    "  $TEST_GO_SCRIPT:3 main")
  assert_failure "${expected[@]}"
}

@test "$SUITE: error if module returns an error" {
  # These correspond to the 'internal-test' module.
  local module="${IMPORTS[1]}"
  local module_file="${TEST_MODULES[3]}"
  local error_message='These violent delights have violent ends...'

  echo "echo '$error_message' >&2" > "$module_file"
  echo "return 1" >> "$module_file"
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"

  local expected=("${IMPORTS[0]##*/} loaded"
    "$error_message"
    "ERROR: Failed to import $module module from $module_file at:"
    "  $TEST_GO_SCRIPT:3 main")
  assert_failure "${expected[@]}"
}

@test "$SUITE: import order: injected; core; internal; exported; plugin" {
  local module_dir='go-use-modules-test'
  local module_name='test-module'
  local module_path="$module_dir/$module_name"

  @go.create_module_test_stub "$module_path" 'printf "INJECTED\n"'

  mkdir -p "$_GO_CORE_DIR/lib/${module_dir}" \
    "$TEST_GO_SCRIPTS_DIR/lib/${module_dir}" \
    "$TEST_GO_ROOTDIR/lib/${module_dir}" \
    "$TEST_GO_PLUGINS_DIR/${module_dir}/lib" \

  printf '%s\n' 'printf "CORE\n"' >"$_GO_CORE_DIR/lib/$module_path"
  printf '%s\n' 'printf "INTERNAL\n"' >"$TEST_GO_SCRIPTS_DIR/lib/$module_path"
  printf '%s\n' 'printf "EXPORTED\n"' >"$TEST_GO_ROOTDIR/lib/$module_path"
  printf '%s\n' 'printf "PLUGIN\n"' \
    >"$TEST_GO_PLUGINS_DIR/${module_dir}/lib/${module_name}"

  @go.create_test_go_script ". \"\$_GO_USE_MODULES\" '${module_path}'"
  run "$TEST_GO_SCRIPT"
  assert_success 'INJECTED'

  rm "$_GO_INJECT_MODULE_PATH/$module_path"
  run "$TEST_GO_SCRIPT"
  assert_success 'CORE'

  rm "$_GO_CORE_DIR/lib/$module_path"
  run "$TEST_GO_SCRIPT"
  assert_success 'INTERNAL'

  rm "$TEST_GO_SCRIPTS_DIR/lib/$module_path"
  run "$TEST_GO_SCRIPT"
  assert_success 'EXPORTED'

  rm "$TEST_GO_ROOTDIR/lib/$module_path"
  run "$TEST_GO_SCRIPT"
  assert_success 'PLUGIN'
}
