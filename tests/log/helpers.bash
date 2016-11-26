#! /bin/bash
#
# Helper functions for `lib/log` tests.

run_log_script() {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" "$@"
  run "$TEST_GO_SCRIPT"
}

# For tests that run command scripts via @go, set _GO_CMD to make sure that's
# the variable included in the log.
test-go() {
  env _GO_CMD="$FUNCNAME" "$TEST_GO_SCRIPT" "$@"
}

format_label() {
  local label="$1"

  if [[ -z "$__GO_LOG_INIT" ]]; then
    . "$_GO_CORE_DIR/lib/log"
    _GO_LOG_FORMATTING='true'
    _@go.log_init
  fi

  local __go_log_level_index=0
  if ! _@go.log_level_index "$label"; then
    echo "Unknown log level label: $label" >&2
    return 1
  fi
  echo "${__GO_LOG_LEVELS_FORMATTED[$__go_log_level_index]}"
}

__expected_log_line() {
  local level="$1"
  local message="$2"

  if [[ "${level:0:3}" == '\e[' ]]; then
    stripped_level="${level//\\e\[[0-9]m}"
    stripped_level="${stripped_level//\\e\[[0-9][0-9]m}"
    stripped_level="${stripped_level//\\e\[[0-9][0-9][0-9]m}"
    level="${level}${padding:0:$((${#padding} - ${#stripped_level}))}"
    echo -e "$level $message\e[0m"
  else
    level="${level}${padding:0:$((${#padding} - ${#level}))}"
    echo "$level $message"
  fi
}

assert_log_equals() {
  set +o functrace
  local level
  local padding=''
  local expected=()
  local __go_log_level_index
  local i

  . "$_GO_CORE_DIR/lib/log"
  for level in "${_GO_LOG_LEVELS[@]}"; do
    while [[ "${#padding}" -lt "${#level}" ]]; do
      padding+=' '
    done
  done

  for ((i=0; $# != 0; ++i)); do
    if _@go.log_level_index "$1" || [[ "$1" =~ ^\\e\[ ]]; then
      expected+=("$(__expected_log_line "$1" "$2")")
      if ! shift 2; then
        echo "ERROR: Wrong number of arguments for log line $i." >&2
        return_from_bats_assertion "$BASH_SOURCE" 1
        return
      fi
    else
      expected+=("$1")
      shift
    fi
  done

  if ! assert_lines_equal "${expected[@]}"; then
    set +o functrace
    return_from_bats_assertion "$BASH_SOURCE" 1
  fi
}
