#! /bin/bash
#
# Helper functions for core library tests

declare -x _GO_CORE_STACK_TRACE_COMPONENTS=()

set_go_core_stack_trace_components() {
  local go_core_file="$_GO_CORE_DIR/go-core.bash"
  local stack_item
  local IFS=$'\n'

  if [[ "${#_GO_CORE_STACK_TRACE_COMPONENTS[@]}" -ne '0' ]]; then
    return
  fi

  create_test_go_script '@go "$@"'
  create_test_command_script 'print-stack-trace' '@go.print_stack_trace'

  for stack_item in $("$TEST_GO_SCRIPT" 'print-stack-trace'); do
    if [[ "$stack_item" =~ $go_core_file ]]; then
      _GO_CORE_STACK_TRACE_COMPONENTS+=("$stack_item")
    elif [[ "${#_GO_CORE_STACK_TRACE_COMPONENTS[@]}" -ne '0' ]]; then
      return
    fi
  done
}
