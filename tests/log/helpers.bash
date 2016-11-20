#! /bin/bash
#
# Helper functions for `lib/log` tests.

run_log_script() {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" "$@"
  run "$TEST_GO_SCRIPT"
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

__all_output_consumed() {
  local index="$1"
  local remaining_lines="$((${#lines[@]} - index))"

  if [[ "$remaining_lines" -gt '0' ]]; then
    if [[ "$remaining_lines" -eq '1' ]]; then
      echo "There is one more line of output than expected:" >&2
    else
      echo "There are $remaining_lines more lines of output than expected:" >&2
    fi
    local IFS=$'\n'
    echo "${lines[*]:$index}" >&2
    return 1

  elif [[ "$remaining_lines" -lt '0' ]]; then
    remaining_lines="$((-remaining_lines))"
    if [[ "$remaining_lines" -eq '1' ]]; then
      echo "There is one fewer line of output than expected." >&2
    else
      echo "There are $remaining_lines fewer lines of output than expected." >&2
    fi
    return 1
  fi
}

assert_log_equals() {
  local level
  local padding=''
  local expected_line
  local num_errors=0
  local remaining_lines=0
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
      expected_line="$(__expected_log_line "$1" "$2")"
      if ! shift 2; then
        echo "ERROR: Wrong number of arguments for log line $i." >&2
        return 1
      fi
    else
      expected_line="$1"
      shift
    fi

    if ! assert_equal "$expected_line" "${lines[$i]}" "line $i"; then
      ((++num_errors))
    fi
    set +o functrace
  done

  if ! __all_output_consumed "$i"; then
    ((++num_errors))
  fi

  if [[ "$num_errors" -ne '0' ]]; then
    return_from_bats_assertion "$BASH_SOURCE" 1
  fi
}
