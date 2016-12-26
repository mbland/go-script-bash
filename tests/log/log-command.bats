#! /usr/bin/env bats

load ../environment
load helpers

setup() {
  # Test every case with a log file as well.
  export TEST_LOG_FILE="$TEST_GO_ROOTDIR/run.log"
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: log single command" {
  run_log_script '@go.log_command echo Hello, World!'
  assert_success

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    'Hello, World!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: logging to a file doesn't repeat lines or skip other log files" {
  local info_log="$TEST_GO_ROOTDIR/info.log"

  run_log_script \
    'function function_that_logs_info() {' \
    '  @go.log INFO "$@"' \
    '  "$@"' \
    '}' \
    "@go.log_add_output_file '$info_log' INFO" \
    '@go.log INFO Invoking _GO_SCRIPT: $_GO_SCRIPT' \
    '@go.log_command function_that_logs_info echo Hello, World!'
  assert_success

  local expected_log_lines=(
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT"
    RUN  'function_that_logs_info echo Hello, World!'
    INFO 'echo Hello, World!'
    'Hello, World!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
  assert_log_file_equals "$info_log" \
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT" \
    INFO 'echo Hello, World!'
}

@test "$SUITE: log single failing command to standard error" {
  run_log_script \
      'function failing_function() {' \
      '  printf "%s\n" "\e[1m$*\e[0m" >&2' \
      '  exit 127' \
      '}' \
      '@go.log_command failing_function foo bar baz'
  assert_failure

  local expected_log_lines=(
    RUN 'failing_function foo bar baz'
    '\e[1mfoo bar baz\e[0m'
    ERROR 'failing_function foo bar baz (exit status 127)')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log failing command to standard error with formatting" {
  local formatted_run_level_label="$(format_label RUN)"
  local formatted_error_level_label="$(format_label ERROR)"

  _GO_LOG_FORMATTING='true' run_log_script \
      'function failing_function() {' \
      '  printf "%s\n" "\e[1m$*\e[0m" >&2' \
      '  exit 127' \
      '}' \
      '@go.log_command failing_function foo bar baz'
  assert_failure

  local expected_log_lines=(
    "$formatted_run_level_label" 'failing_function foo bar baz'
    "$(printf '%b' '\e[1mfoo bar baz\e[0m')"
    "$formatted_error_level_label"
      'failing_function foo bar baz (exit status 127)')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log single failing command in critical section" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command failing_function foo bar baz' \
    '@go.critical_section_end'
  assert_failure

  local expected_log_lines=(
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "$(test_script_stack_trace_item 1)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log single failing command without executing during dry run" {
  _GO_DRY_RUN='true' run_log_script \
    'failing_function() { return 127; }' \
    '@go.log_command failing_function foo bar baz'
  assert_success

  assert_log_equals RUN 'failing_function foo bar baz'
  assert_log_file_equals "$TEST_LOG_FILE" \
    RUN 'failing_function foo bar baz'
}

@test "$SUITE: log multiple commands" {
  run_log_script '@go.log_command echo Hello, World!' \
    "@go.log_command echo I don\'t know why you say goodbye," \
    '@go.log_command echo while I say hello...'
  assert_success

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN "echo I don't know why you say goodbye,"
    "I don't know why you say goodbye,"
    RUN "echo while I say hello..."
    "while I say hello...")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log multiple commands, second one fails" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!'
  assert_success

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN "failing_function foo bar baz"
    ERROR 'failing_function foo bar baz (exit status 127)'
    RUN "echo Goodbye, World!"
    "Goodbye, World!")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log multiple commands, second one fails in critical section" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!' \
    '@go.critical_section_end'
  assert_failure

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN "failing_function foo bar baz"
    FATAL 'failing_function foo bar baz (exit status 127)'
    "$(test_script_stack_trace_item 2)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log multiple commands without executing during dry run" {
  _GO_DRY_RUN=true run_log_script \
    'failing_function() { return 127; }' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!'
  assert_success

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    RUN "failing_function foo bar baz"
    RUN 'echo Goodbye, World!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: critical section in function" {
  # This reproduces a bug whereby @go.critical_section_end will return an error
  # status because of its decrementing a variable to zero, resulting in an ERROR
  # log for `critical subsection`.
  run_log_script 'failing_function() { return 127; }' \
    'critical_subsection() {' \
    '  @go.critical_section_begin' \
    '  @go.log_command echo $*' \
    '  @go.critical_section_end' \
    '}' \
    '@go.log_command critical_subsection Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo We made it!'
  assert_success

  local expected_log_lines=(
    RUN 'critical_subsection Hello, World!'
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN 'failing_function foo bar baz'
    ERROR 'failing_function foo bar baz (exit status 127)'
    RUN 'echo We made it!'
    'We made it!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: nested critical sections" {
  run_log_script 'failing_function() { return 127; }' \
    'critical_subsection() {' \
    '  @go.critical_section_begin' \
    '  @go.log_command echo $*' \
    '  @go.critical_section_end' \
    '}' \
    '@go.critical_section_begin' \
    '@go.log_command critical_subsection Hello, World!' \
    '@go.critical_section_end' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo We made it!'
  assert_success

  local expected_log_lines=(
    RUN 'critical_subsection Hello, World!'
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN 'failing_function foo bar baz'
    ERROR 'failing_function foo bar baz (exit status 127)'
    RUN 'echo We made it!'
    'We made it!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: nested critical sections dry run" {
  # Note that `echo Hello, World!` inside `critical_subsection` isn't logged,
  # since `critical_subsection` is only logged but not executed.
  _GO_DRY_RUN='true' run_log_script \
    'failing_function() { return 127; }' \
    'critical_subsection() {' \
    '  @go.critical_section_begin' \
    '  @go.log_command echo $*' \
    '  @go.critical_section_end' \
    '}' \
    '@go.critical_section_begin' \
    '@go.log_command critical_subsection Hello, World!' \
    '@go.critical_section_end' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo We made it!'
  assert_success

  local expected_log_lines=(
    RUN 'critical_subsection Hello, World!'
    RUN 'failing_function foo bar baz'
    RUN 'echo We made it!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: critical section is reentrant" {
  run_log_script 'failing_function() { return 127; }' \
    'critical_subsection() {' \
    '  @go.critical_section_begin' \
    '  @go.log_command echo $*' \
    '  @go.critical_section_end' \
    '}' \
    '@go.critical_section_begin' \
    '@go.log_command critical_subsection Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.critical_section_end' \
    "@go.log_command echo We shouldn\'t make it this far..."
  assert_failure

  local expected_log_lines=(
    RUN 'critical_subsection Hello, World!'
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "$(test_script_stack_trace_item 2)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: critical section counter does not go below zero" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command echo Hello, World!' \
    '@go.critical_section_end' \
    '@go.critical_section_end' \
    '@go.critical_section_end' \
    '@go.log_command failing_function foo bar baz' \
    '@go.critical_section_begin' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command Should not get this far' \
    '@go.critical_section_end'
  assert_failure

  local expected_log_lines=(
    RUN 'echo Hello, World!'
    'Hello, World!'
    RUN 'failing_function foo bar baz'
    ERROR 'failing_function foo bar baz (exit status 127)'
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "$(test_script_stack_trace_item 2)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: log and run command script using @go" {
  create_log_script ". \"\$_GO_USE_MODULES\" 'log'" \
    '@go.log_command @go project-command-script "$@"'

  create_test_command_script 'project-command-script' 'echo $*'

  run test-go Hello, World!
  assert_success

  local expected_log_lines=(
    RUN 'test-go project-command-script Hello, World!'
    'Hello, World!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: critical section in parent script applies to command script" {
  create_log_script \
    '@go.critical_section_begin' \
    '@go.log_command @go project-command-script "$@"' \
    '@go.critical_section_end' \
    '@go.log_command Should not get this far.'

  create_test_command_script 'project-command-script' \
    'failing_function() { return 127; }' \
    '@go.log_command failing_function "$@"'

  run test-go foo bar baz
  assert_failure
  set_go_core_stack_trace_components
  set_log_command_stack_trace_items

  local expected_log_lines=(
    RUN 'test-go project-command-script foo bar baz'
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "  $TEST_GO_SCRIPTS_DIR/project-command-script:3 source"
    "${GO_CORE_STACK_TRACE_COMPONENTS[@]}"
    "${LOG_COMMAND_STACK_TRACE_ITEMS[@]}"
    "$(test_script_stack_trace_item 2)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: critical section in command script applies to parent script" {
  create_log_script \
    '@go.log_command @go project-command-script "$@"' \
    '@go.log_command Should not get this far.'

  create_test_command_script 'project-command-script' \
    'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command failing_function "$@"' \
    '@go.critical_section_end'

  run test-go foo bar baz
  assert_failure
  set_go_core_stack_trace_components
  set_log_command_stack_trace_items

  local expected_log_lines=(
    RUN 'test-go project-command-script foo bar baz'
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "  $TEST_GO_SCRIPTS_DIR/project-command-script:4 source"
    "${GO_CORE_STACK_TRACE_COMPONENTS[@]}"
    "${LOG_COMMAND_STACK_TRACE_ITEMS[@]}"
    "$(test_script_stack_trace_item 1)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: exit/fatal status pattern applies only when last line printed" {
  create_log_script '@go.log_command @go project-command-script "$@"'

  create_test_command_script 'project-command-script' \
    'echo @go.log_command fatal:127' \
    'echo @go.log_command exit:127'

  run test-go
  assert_success
  # Note that the "fake" exit status lines gets swallowed.
  assert_log_equals RUN 'test-go project-command-script'
  assert_log_file_equals "$TEST_LOG_FILE" RUN 'test-go project-command-script'
}

@test "$SUITE: capture sourced script exit status when not from @go.log FATAL" {
  create_log_script \
    '@go.critical_section_begin' \
    "@go.log_command . '$TEST_GO_SCRIPTS_RELATIVE_DIR/sourced-script'" \
    '@go.critical_section_end'

  create_test_command_script 'sourced-script' \
    'exit 127'

  run test-go
  assert_failure

  # Note that the `@go.log_command` and `go-core.bash` items aren't in the stack
  # trace.
  local expected_log_lines=(
    RUN ". $TEST_GO_SCRIPTS_RELATIVE_DIR/sourced-script"
    FATAL ". $TEST_GO_SCRIPTS_RELATIVE_DIR/sourced-script (exit status 127)"
    "$(test_script_stack_trace_item 1)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: exit status from subcommand in other language" {
  if ! command -v perl &>/dev/null; then
    skip 'perl not installed'
  fi

  create_log_script \
    '@go.critical_section_begin' \
    '@go.log_command @go "$@"' \
    '@go.critical_section_end'

  create_test_command_script 'perl-command-script' \
    '#!/bin/perl' \
    'print "@ARGV\n";' \
    'exit 127;'

  run test-go perl-command-script foo bar baz
  assert_failure

  local expected_log_lines=(
    RUN "test-go perl-command-script foo bar baz"
    'foo bar baz'
    FATAL "test-go perl-command-script foo bar baz (exit status 127)"
    "$(test_script_stack_trace_item 1)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: fatal status for subcommand of command in another language" {
  if ! command -v perl &>/dev/null; then
    skip 'perl not installed'
  fi

  create_log_script \
    '@go.critical_section_begin' \
    '@go.log_command @go "$@"' \
    '@go.critical_section_end'

  # For this to work, scripts in other languages have to take care to return the
  # exit status from the failed command, especially if
  # `__GO_LOG_CRITICAL_SECTION` is in effect.
  create_test_command_script 'perl-command-script' \
    '#!/bin/perl' \
    'print "@ARGV\n";' \
    "my @args = ('bash', \$ENV{'_GO_SCRIPT'}, 'bash-command-script');" \
    'push @args, @ARGV;' \
    "if (system(@args) != 0 && \$ENV{'__GO_LOG_CRITICAL_SECTION'} != 0) {" \
    '  exit $? >> 8;' \
    '}'

  # Note that the critical section still applies, since
  # `__GO_LOG_CRITICAL_SECTION` is exported.
  create_test_command_script 'bash-command-script' \
    'failing_function() { return 127; }' \
    '@go.log_command failing_function "$@"' \

  run test-go perl-command-script foo bar baz
  assert_failure
  set_go_core_stack_trace_components
  set_log_command_stack_trace_items

  # Notice there's two FATAL stack traces:
  # - The first is from the bash-command-script, which is insulated from the
  #   top-level `TEST_GO_SCRIPT` invocation by the perl-command-script.
  # - The second is from the top-level `TEST_GO_SCRIPT`, based on the return
  #   status from the perl-command-script.
  local expected_log_lines=(
    RUN "test-go perl-command-script foo bar baz"
    'foo bar baz'
    RUN "test-go bash-command-script foo bar baz"
    RUN 'failing_function foo bar baz'
    FATAL 'failing_function foo bar baz (exit status 127)'
    "  $TEST_GO_SCRIPTS_DIR/bash-command-script:3 source"
    "${GO_CORE_STACK_TRACE_COMPONENTS[@]}"
    "${LOG_COMMAND_STACK_TRACE_ITEMS[@]}"
    "$(test_script_stack_trace_item 1)"
    FATAL 'test-go perl-command-script foo bar baz (exit status 127)'
    "$(test_script_stack_trace_item 1)")

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
}

@test "$SUITE: subcommand of command in other language appends to all logs" {
  if ! command -v perl &>/dev/null; then
    skip 'perl not installed'
  fi

  local info_log="$TEST_GO_ROOTDIR/info.log"

  create_log_script \
    "@go.log_add_output_file '$info_log' INFO" \
    '@go.log INFO Invoking _GO_SCRIPT: $_GO_SCRIPT' \
    '@go.log_command @go "$@"' \

  create_test_command_script 'perl-command-script' \
    '#!/bin/perl' \
    'print "@ARGV\n";' \
    "my @args = ('bash', \$ENV{'_GO_SCRIPT'}, 'bash-command-script');" \
    'push @args, @ARGV;' \
    "if (system(@args) != 0) {" \
    '  exit $? >> 8;' \
    '}'

  create_test_command_script 'bash-command-script' \
    'function function_that_logs_info() {' \
    '  @go.log INFO "$@"' \
    '  "$@"' \
    '}' \
    '@go.log_command function_that_logs_info "$@"'

  run test-go perl-command-script echo Hello, World!
  assert_success

  local expected_log_lines=(
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT"
    RUN "test-go perl-command-script echo Hello, World!"
    'echo Hello, World!'
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT"
    RUN "test-go bash-command-script echo Hello, World!"
    RUN 'function_that_logs_info echo Hello, World!'
    INFO 'echo Hello, World!'
    'Hello, World!')

  assert_log_equals "${expected_log_lines[@]}"
  assert_log_file_equals "$TEST_LOG_FILE" "${expected_log_lines[@]}"
  assert_log_file_equals "$info_log" \
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT" \
    INFO "Invoking _GO_SCRIPT: $TEST_GO_SCRIPT" \
    INFO 'echo Hello, World!'
}
