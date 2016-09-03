#! /bin/bash
#
# Framework for writing "./go" scripts in Bash.
#
# URL: https://github.com/mbland/go-script-bash
#
# To use this framework, create a bash script in the root directory of your
# project to act as the main './go' script. This script need not be named 'go',
# but it must contain the following as the first and last executable lines,
# respectively:
#
#   . "${0%/*}/go-core.bash" "scripts"
#   @go "$@"
#
# where "${0%/*}" produces the path to the project's root directory,
# "go-core.bash" is the path to this file, and "scripts" is the path to the
# directory holding the project's command scripts relative to the project root.
#
# Inspired by:
# - "In Praise of the ./go Script: Parts I and II" by Pete Hodgson
#   https://www.thoughtworks.com/insights/blog/praise-go-script-part-i
#   https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii
# - rbenv: https://github.com/rbenv/rbenv
#
# Author: Mike Bland <mbland@acm.org>
#           https://mike-bland.com/
#           https://github.com/mbland

if [[ "${BASH_VERSINFO[0]}" -lt '3' || "${BASH_VERSINFO[1]}" -lt '2' ]]; then
  printf "This module requires bash version 3.2 or greater:\n  %s %s\n" \
    $BASH $BASH_VERSION
  exit 1
fi

declare __go_orig_dir="$PWD"
cd "${0%/*}"

# Path to the project's root directory
#
# This is directory containing the main ./go script. All functions, commands,
# and scripts are invoked relative to this directory.
declare -r -x _GO_ROOTDIR="$PWD"

# Path to the main ./go script in the project's root directory
declare -r -x _GO_SCRIPT="$_GO_ROOTDIR/${0##*/}"

declare -r _GO_CMD="${_GO_CMD:=$0}"
declare -r _GO_CORE_URL='https://github.com/mbland/go-script-bash'

cd "$__go_orig_dir"
cd "${BASH_SOURCE[0]%/*}"
declare -r _GO_CORE_DIR="$PWD"
cd "$_GO_ROOTDIR"

# Invokes printf builtin, then folds output to $COLUMNS width if 'fold' exists.
#
# Should be used as the last step to print to standard output, as that is more
# efficient than calling this multiple times due to the pipe to 'fold'.
#
# Arguments:
#   everything accepted by the printf builtin except the '-v varname' option
@go.printf() {
  if command -v fold >/dev/null; then
    printf "$@" | fold -s -w $COLUMNS
  else
    printf "$@"
  fi
}

# Main driver of ./go script functionality.
#
# Arguments:
#   $1: name of the command to invoke
#   $2..$#: arguments to the specified command
@go() {
  local cmd="$1"
  shift

  case "$cmd" in
  '')
    _@go.source_builtin 'help' 1>&2
    return 1
    ;;
  -h|-help|--help)
    cmd='help'
    ;;
  -*)
    @go.printf "Unknown flag: $cmd\n\n"
    _@go.source_builtin 'help' 1>&2
    return 1
    ;;
  edit)
    "$EDITOR" "$@"
    return
    ;;
  run)
    "$@"
    return
    ;;
  cd|pushd|unenv)
    @go.printf "$cmd is only available after using \"$_GO_CMD env\" %s\n" \
      "to set up your shell environment." >&2
    return 1
    ;;
  esac

  if _@go.source_builtin 'aliases' --exists "$cmd"; then
    "$cmd" "$@"
    return
  fi

  . "$_GO_CORE_DIR/lib/path"
  local __go_cmd_path
  local __go_argv

  if ! _@go.set_command_path_and_argv "$cmd" "$@"; then
    return 1
  fi
  _@go.run_command_script "$__go_cmd_path" "${__go_argv[@]}"
}

_@go.source_builtin() {
  local c="$1"
  shift
  . "$_GO_CORE_DIR/libexec/$c"
}

_@go.run_command_script() {
  local cmd_path="$1"
  shift

  local interpreter
  read -r interpreter < "$cmd_path"

  if [[ "${interpreter:0:2}" != '#!' ]]; then
    @go.printf \
      "The first line of %s does not contain #!/path/to/interpreter.\n" \
      "$cmd_path" >&2
    return 1
  fi

  interpreter="${interpreter:2}"
  interpreter="${interpreter#*/env }"
  interpreter="${interpreter##*/}"
  interpreter="${interpreter%% *}"

  if [[ "$interpreter" = 'bash' || "$interpreter" = 'sh' ]]; then
    . "$cmd_path" "$@"
  elif [[ -n "$interpreter" ]]; then
    "$interpreter" "$cmd_path" "$@"
  else
    @go.printf "Could not parse interpreter from first line of $cmd_path.\n"
    return 1
  fi
}

_@go.check_scripts_dir() {
  local scripts_dir="$_GO_ROOTDIR/$1"

  if [[ "$#" -ne '1' ]]; then
    echo "ERROR: there should be exactly one command script dir specified" >&2
    return 1
  elif [[ ! -e "$scripts_dir" ]]; then
    echo "ERROR: command script directory $scripts_dir does not exist" >&2
    return 1
  elif [[ ! -d "$scripts_dir" ]]; then
    echo "ERROR: $scripts_dir is not a directory" >&2
    return 1
  elif [[ ! -r "$scripts_dir" || ! -x "$scripts_dir" ]]; then
    echo "ERROR: you do not have permission to access the $scripts_dir" \
      "directory" >&2
    return 1
  fi
}

if ! _@go.check_scripts_dir "$@"; then
  exit 1
fi

if [[ -z "$COLUMNS" ]]; then
  if command -v 'tput' >/dev/null; then
    COLUMNS="$(tput cols)"
  elif command -v 'mode.com' >/dev/null; then
    COLUMNS="$(mode.com) con:"
    shopt -s extglob
    COLUMNS="${COLUMNS#*Columns:+( )}"
    shopt -u extglob
    COLUMNS="${COLUMNS%% *}"
  else
    COLUMNS=80
  fi
  export COLUMNS
fi

cd "$1"
declare -r _GO_SCRIPTS_DIR="$PWD"
cd - >/dev/null
