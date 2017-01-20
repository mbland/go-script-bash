#! /bin/bash
#
# Helper functions for `./go commands` tests.

declare BUILTIN_CMDS
declare BUILTIN_SCRIPTS
declare LONGEST_BUILTIN_NAME

find_builtins() {
  local cmd_script
  local cmd_name

  for cmd_script in "$_GO_ROOTDIR"/libexec/*; do
    if [[ ! (-f "$cmd_script" && -x "$cmd_script") ]]; then
      continue
    fi
    cmd_name="${cmd_script##*/}"
    BUILTIN_CMDS+=("$cmd_name")
    BUILTIN_SCRIPTS+=("$cmd_script")

    if [[ "${#cmd_name}" -gt "${#LONGEST_BUILTIN_NAME}" ]]; then
      LONGEST_BUILTIN_NAME="$cmd_name"
    fi
  done

  # Strip the rootdir to make output less noisy.
  BUILTIN_SCRIPTS=("${BUILTIN_SCRIPTS[@]#$_GO_ROOTDIR/}")
}

merge_scripts() {
  local args=("$@")
  local i=0
  local j=0
  local lhs
  local rhs
  local result=()

  while ((i != ${#__all_scripts[@]} && j != ${#args[@]})); do
    lhs="${__all_scripts[$i]##*/}"
    rhs="${args[$j]##*/}"

    if [[ "$lhs" < "$rhs" ]]; then
      result+=("${__all_scripts[$i]}")
      ((++i))
    elif [[ "$lhs" == "$rhs" ]]; then
      result+=("${__all_scripts[$i]}")
      ((++i))
      ((++j))
    else
      result+=("${args[$j]}")
      ((++j))
    fi
  done

  __all_scripts=("${result[@]}" "${__all_scripts[@]:$i}" "${args[@]:$j}")
}

add_scripts() {
  local script_names=("$@")

  merge_scripts "${script_names[@]/#/$TEST_GO_SCRIPTS_RELATIVE_DIR/}"

  for script_path in "${script_names[@]}"; do
    @go.create_test_command_script "$script_path"
  done
}
