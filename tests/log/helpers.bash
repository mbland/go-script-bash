#! /bin/bash
#
# Helper functions for `lib/log` tests.

run_log_script() {
  create_test_go_script \
    ". \"\$_GO_USE_MODULES\" 'log'" \
    'if [[ -n "$TEST_LOG_FILE" ]]; then' \
    '  @go.log_add_output_file "$TEST_LOG_FILE"' \
    'fi' \
    "$@"
  run "$TEST_GO_SCRIPT"
}

# For tests that run command scripts via @go, set _GO_CMD to make sure that's
# the variable included in the log.
test-go() {
  env _GO_CMD="$FUNCNAME" "$TEST_GO_SCRIPT" "$@"
}

# Note that this must be called before any other log assertion, because it needs
# to set _GO_LOG_FORMATTING before importing the `log` module.
format_label() {
  local label="$1"

  if [[ -n "$__GO_LOG_INIT" ]]; then
    echo "$FUNCNAME must be called before any other function or assertion" \
      "that calls \`. \$_GO_USE_MODULES 'log'\` because it needs to set" \
      "\`_GO_LOG_FORMATTING\`." >&2
      return 1
  fi

  _GO_LOG_FORMATTING='true'
  . "$_GO_USE_MODULES" 'log'
  _@go.log_init

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
    printf '%b\n' "$level $message\e[0m"
  else
    level="${level}${padding:0:$((${#padding} - ${#level}))}"
    printf '%b\n' "$level $message"
  fi
}

assert_log_equals() {
  set +o functrace
  local level
  local padding=''
  local expected=()
  local __go_log_level_index
  local i
  local result=0

  . "$_GO_USE_MODULES" 'log'

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
    result=1
  fi
  set +o functrace
  return_from_bats_assertion "$BASH_SOURCE" "$result"
}

assert_log_file_equals() {
  local log_file="$1"
  shift
  local origIFS="$IFS"
  local IFS=$'\n'
  local log_content=($(< "$log_file"))
  local result=0

  run echo "${log_content[*]}"
  IFS="$origIFS"

  if ! assert_log_equals "$@"; then
    result=1
  fi
  set +o functrace
  return_from_bats_assertion "$BASH_SOURCE" "$result"
}
