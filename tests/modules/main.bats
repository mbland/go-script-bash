#! /usr/bin/env bats

load ../environment
load helpers

LAST_CORE_MODULE=
LAST_CORE_MODULE_PATH=

FIRST_CORE_MOD_SUMMARY=
LAST_CORE_MOD_SUMMARY=

setup() {
  create_test_go_script '@go "$@"'
  setup_test_modules

  local last_index="$((${#CORE_MODULES[@]} - 1))"
  LAST_CORE_MODULE="${CORE_MODULES[$last_index]}"
  LAST_CORE_MODULE_PATH="${CORE_MODULES_PATHS[$last_index]}"
}

teardown() {
  remove_test_go_rootdir
}

get_first_and_last_core_module_summaries() {
  local module
  local __go_cmd_desc

  . "$_GO_ROOTDIR/lib/internal/command_descriptions"
  _@go.command_summary "${CORE_MODULES_PATHS[0]}"
  FIRST_CORE_MOD_SUMMARY="$__go_cmd_desc"
  _@go.command_summary "$LAST_CORE_MODULE_PATH"
  LAST_CORE_MOD_SUMMARY="$__go_cmd_desc"
}

@test "$SUITE: error if unknown option" {
  run "$TEST_GO_SCRIPT" modules --bogus-flag
  assert_failure 'Unknown option: --bogus-flag'
}

@test "$SUITE: error if --imported is followed by arguments" {
  run "$TEST_GO_SCRIPT" modules --imported foo bar
  assert_failure 'The --imported option takes no other arguments.'
}

@test "$SUITE: error if '*' accompanied by other glob patterns" {
  run "$TEST_GO_SCRIPT" modules '_f*' '*' '_b*'
  assert_failure "Do not specify other patterns when '*' is present."
}

@test "$SUITE: error if parsing summary fails" {
  if fs_missing_permission_support; then
    skip "Can't trigger condition on this file system"
  elif [[ "$EUID" -eq '0' ]]; then
    skip "Can't trigger condition when run by superuser"
  fi

  local module_path="$TEST_GO_PLUGINS_DIR/_foo/lib/_plugh"
  chmod ugo-r "$module_path"
  run "$TEST_GO_SCRIPT" 'modules' '--summaries' '_foo/_plugh'
  assert_failure
  assert_output_matches "ERROR: failed to parse summary from $module_path\$"
}

@test "$SUITE: error if module spec without glob doesn't match anything" {
  run "$TEST_GO_SCRIPT" 'modules' 'some-bogus-module'
  assert_failure 'Unknown module: some-bogus-module'
}

@test "$SUITE: --imported" {
  create_test_go_script \
    '. "$_GO_USE_MODULES" "complete" "_foo/_plugh" "_bar/_quux" "_frotz"' \
    '@go "$@"'

  # The first will be an absolute path because the script's _GO_ROOTDIR doesn't
  # contain the framework sources.
  local expected=(
    "complete     $_GO_ROOTDIR/lib/complete"
    "_foo/_plugh  scripts/plugins/_foo/lib/_plugh"
    "_bar/_quux   scripts/plugins/_bar/lib/_quux"
    "_frotz       scripts/lib/_frotz"
  )

  run "$TEST_GO_SCRIPT" modules --imported
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list by class, all modules" {
  local expected=('From the core framework library:'
    "${CORE_MODULES[@]/#/  }"
    ''
    'From the installed plugin libraries:'
    "${TEST_PLUGIN_MODULES[@]/#/  }"
    ''
    'From the project library:'
    "${TEST_PROJECT_MODULES[@]/#/  }"
  )

  run "$TEST_GO_SCRIPT" modules
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list using glob, all modules" {
  local expected=("${CORE_MODULES[@]}"
    "${TEST_PLUGIN_MODULES[@]}"
    "${TEST_PROJECT_MODULES[@]}"
  )

  run "$TEST_GO_SCRIPT" modules '*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list by class, only core modules present" {
  local expected=('From the core framework library:'
    "${CORE_MODULES[@]/#/  }"
  )

  rm "${TEST_PLUGIN_MODULES_PATHS[@]/#/$TEST_GO_ROOTDIR/}" \
    "${TEST_PROJECT_MODULES_PATHS[@]/#/$TEST_GO_ROOTDIR/}"
  run "$TEST_GO_SCRIPT" modules
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list using glob, only core modules present" {
  rm "${TEST_PLUGIN_MODULES_PATHS[@]/#/$TEST_GO_ROOTDIR/}" \
    "${TEST_PROJECT_MODULES_PATHS[@]/#/$TEST_GO_ROOTDIR/}"
  run "$TEST_GO_SCRIPT" modules '*'
  local IFS=$'\n'
  assert_success "${CORE_MODULES[*]}"
}

@test "$SUITE: paths by class" {
  run "$TEST_GO_SCRIPT" modules --paths
  assert_success

  # Note the two newlines at the end of each class section.
  assert_output_matches "  ${CORE_MODULES[0]} +${CORE_MODULES_PATHS[0]}"$'\n'
  assert_output_matches "  $LAST_CORE_MODULE +$LAST_CORE_MODULE_PATH"$'\n'$'\n'

  # Note the padding is relative to only the plugin modules. Use a variable to
  # keep the assertion lines under 80 columns.
  local plugins='scripts/plugins'
  assert_output_matches "  _bar/_plugh  $plugins/_bar/lib/_plugh"$'\n'
  assert_output_matches "  _foo/_quux   $plugins/_foo/lib/_quux"$'\n'
  assert_output_matches "  _foo/_xyzzy  $plugins/_foo/lib/_xyzzy"$'\n'$'\n'

  # Note the padding is relative to only the project modules. Bats trims
  # the last newline of the output.
  assert_output_matches "  _frobozz  scripts/lib/_frobozz"$'\n'
  assert_output_matches "  _frotz    scripts/lib/_frotz$"

  # Since the 'lines' array doesn't contain blank lines, we only add '3' to
  # account for the 'From the...' line starting each class section.
  assert_equal "$((TOTAL_NUM_MODULES + 3))" "${#lines[@]}"
}

@test "$SUITE: paths using glob, all modules" {
  run "$TEST_GO_SCRIPT" modules --paths '*'
  assert_success

  # Note that there is no leading space, the padding is relative to the length
  # of the longest module name overall, and there are no separate sections
  # delimited by back-to-back newlines. Bats trims the final newline.
  assert_output_matches \
    "${CORE_MODULES[0]}  +${CORE_MODULES_PATHS[0]}"$'\n'
  assert_output_matches \
    $'\n'"$LAST_CORE_MODULE  +$LAST_CORE_MODULE_PATH"$'\n'
  assert_output_matches \
    $'\n'"_bar/_plugh  +scripts/plugins/_bar/lib/_plugh"$'\n'
  assert_output_matches \
    $'\n'"_foo/_quux   +scripts/plugins/_foo/lib/_quux"$'\n'
  assert_output_matches \
    $'\n'"_foo/_xyzzy  +scripts/plugins/_foo/lib/_xyzzy"$'\n'
  assert_output_matches \
    $'\n'"_frobozz     +scripts/lib/_frobozz"$'\n'
  assert_output_matches \
    $'\n'"_frotz       +scripts/lib/_frotz$"

  assert_equal "$TOTAL_NUM_MODULES" "${#lines[@]}"
}

@test "$SUITE: summaries by class" {
  run "$TEST_GO_SCRIPT" modules --summaries
  assert_success

  # Note the two newlines at the end of each class section.
  get_first_and_last_core_module_summaries
  assert_output_matches "  ${CORE_MODULES[0]} +$FIRST_CORE_MOD_SUMMARY"$'\n'
  assert_output_matches "  $LAST_CORE_MODULE +$LAST_CORE_MOD_SUMMARY"$'\n'$'\n'

  # Note the padding is relative to only the plugin modules.
  assert_output_matches "  _bar/_plugh  Summary for _bar/_plugh"$'\n'
  assert_output_matches "  _foo/_quux   Summary for _foo/_quux"$'\n'
  assert_output_matches "  _foo/_xyzzy  Summary for _foo/_xyzzy"$'\n'$'\n'

  # Note the padding is relative to only the project modules. Bats trims
  # the last newline of the output.
  assert_output_matches "  _frobozz  Summary for _frobozz"$'\n'
  assert_output_matches "  _frotz    Summary for _frotz$"

  # Since the 'lines' array doesn't contain blank lines, we only add '3' to
  # account for the 'From the...' line starting each class section.
  assert_equal "$((TOTAL_NUM_MODULES + 3))" "${#lines[@]}"
}

@test "$SUITE: summaries using glob, all modules" {
  run "$TEST_GO_SCRIPT" modules --summaries '*'
  assert_success

  # Note that there is no leading space, the padding is relative to the length
  # of the longest module name overall, and there are no separate sections
  # delimited by back-to-back newlines. Bats trims the final newline.
  get_first_and_last_core_module_summaries
  assert_output_matches "${CORE_MODULES[0]}  +$FIRST_CORE_MOD_SUMMARY"$'\n'
  assert_output_matches $'\n'"$LAST_CORE_MODULE  +$LAST_CORE_MOD_SUMMARY"$'\n'
  assert_output_matches $'\n'"_bar/_plugh  +Summary for _bar/_plugh"$'\n'
  assert_output_matches $'\n'"_foo/_quux   +Summary for _foo/_quux"$'\n'
  assert_output_matches $'\n'"_foo/_xyzzy  +Summary for _foo/_xyzzy"$'\n'
  assert_output_matches $'\n'"_frobozz     +Summary for _frobozz"$'\n'
  assert_output_matches $'\n'"_frotz       +Summary for _frotz$"

  assert_equal "$TOTAL_NUM_MODULES" "${#lines[@]}"
}

@test "$SUITE: list only test modules" {
  run "$TEST_GO_SCRIPT" modules '_*'
  local IFS=$'\n'
  assert_success "${TEST_PLUGIN_MODULES[*]}"$'\n'"${TEST_PROJECT_MODULES[*]}"
}

@test "$SUITE: list only test project modules" {
  run "$TEST_GO_SCRIPT" modules '_fr*'
  local IFS=$'\n'
  assert_success "${TEST_PROJECT_MODULES[*]}"
}

@test "$SUITE: list only modules in the _bar and _baz plugins" {
  run "$TEST_GO_SCRIPT" modules '_ba*/_*u*'
  local expected=('_bar/_plugh' '_bar/_quux' '_baz/_plugh' '_baz/_quux')
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: list test modules using multiple globs" {
  # Note that the modules are listed in the order of the globs, so the project
  # modules are listed before the plugin modules.
  run "$TEST_GO_SCRIPT" modules '_frob*' '_f*/_*u*' '_bar/'
  local expected=(
    '_frobozz'
    '_foo/_plugh'
    '_foo/_quux'
    '_bar/_plugh'
    '_bar/_quux'
    '_bar/_xyzzy'
  )
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
