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
  create_test_go_script \
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
  remove_test_go_rootdir
}

@test "$SUITE: no modules imported by default" {
  create_test_go_script 'echo modules: "${_GO_IMPORTED_MODULES[*]}"'
  run "$TEST_GO_SCRIPT"
  assert_success 'modules: '
}

@test "$SUITE: does nothing if no modules specified" {
  run "$TEST_GO_SCRIPT"
  assert_success 'modules: '
}

@test "$SUITE: error if nonexistent module specified" {
  run "$TEST_GO_SCRIPT" 'bogus-test-module'
  assert_failure 'ERROR: Unknown module: bogus-test-module'
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
