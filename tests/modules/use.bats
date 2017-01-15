#! /usr/bin/env bats

load ../environment

TEST_MODULES=(
  "$_GO_ROOTDIR/lib/builtin-test"
  "$TEST_GO_PLUGINS_DIR/test-plugin/lib/plugin-test"
  "$TEST_GO_SCRIPTS_DIR/lib/project-test"
)
IMPORTS=('test-plugin/plugin-test' 'project-test' 'builtin-test')
EXPECTED=(
  "plugin-test loaded"
  "project-test loaded"
  "builtin-test loaded"
  "modules: ${IMPORTS[*]}"
)

setup() {
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
  rm -f "${TEST_MODULES[@]}"
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
  local IFS=$'\n'
  assert_failure "${expected[*]}"
}

@test "$SUITE: import modules successfully" {
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"
  local IFS=$'\n'
  assert_success "${EXPECTED[*]}"
}

@test "$SUITE: import each module only once" {
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}" "${IMPORTS[@]}" "${IMPORTS[@]}"
  local IFS=$'\n'
  assert_success "${EXPECTED[*]}"
}

@test "$SUITE: prevent self, circular, and multiple importing" {
  local module

  for module in "${TEST_MODULES[@]}"; do
    echo ". \"\$_GO_USE_MODULES\" ${IMPORTS[@]}" >> "$module"
  done

  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"
  local IFS=$'\n'
  assert_success "${EXPECTED[*]}"
}

@test "$SUITE: error if module contains errors" {
  local module="${IMPORTS[1]}"
  local module_file="${TEST_MODULES[2]}"

  echo "This is a totally broken module." > "$module_file"
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"

  local expected=("${IMPORTS[0]##*/} loaded"
    "$module_file: line 1: This: command not found"
    "ERROR: Failed to import $module module from $module_file at:"
    "  $TEST_GO_SCRIPT:3 main")
  local IFS=$'\n'
  assert_failure "${expected[*]}"
}

@test "$SUITE: error if module returns an error" {
  local module="${IMPORTS[1]}"
  local module_file="${TEST_MODULES[2]}"
  local error_message='These violent delights have violent ends...'

  echo "echo '$error_message' >&2" > "$module_file"
  echo "return 1" >> "$module_file"
  run "$TEST_GO_SCRIPT" "${IMPORTS[@]}"

  local expected=("${IMPORTS[0]##*/} loaded"
    "$error_message"
    "ERROR: Failed to import $module module from $module_file at:"
    "  $TEST_GO_SCRIPT:3 main")
  local IFS=$'\n'
  assert_failure "${expected[*]}"
}
