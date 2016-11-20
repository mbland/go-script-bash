#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: log single command" {
  run_log_script '@go.log_command echo Hello, World!'
  assert_success
  assert_log_equals RUN 'echo Hello, World!' \
    'Hello, World!'
}

@test "$SUITE: log single failing command" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.log_command failing_function foo bar baz'
  assert_failure
  assert_log_equals RUN 'failing_function foo bar baz' \
    ERROR 'failing_function foo bar baz (exit status 127)'
}

@test "$SUITE: log single failing command in critical section" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command failing_function foo bar baz' \
    '@go.critical_section_end'
  assert_failure
  assert_log_equals RUN 'failing_function foo bar baz' \
    FATAL 'failing_function foo bar baz (exit status 127)'
}

@test "$SUITE: log single failing command without executing during dry run" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    'failing_function() { return 127; }' \
    '@go.log_command failing_function foo bar baz'
  run env _GO_DRY_RUN=true "$TEST_GO_SCRIPT"
  assert_success
  assert_log_equals RUN 'failing_function foo bar baz'
}

@test "$SUITE: log multiple commands" {
  run_log_script '@go.log_command echo Hello, World!' \
    "@go.log_command echo I don\'t know why you say goodbye," \
    '@go.log_command echo while I say hello...'
  assert_success
  assert_log_equals RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN "echo I don't know why you say goodbye," \
    "I don't know why you say goodbye," \
    RUN "echo while I say hello..." \
    "while I say hello..."
}

@test "$SUITE: log multiple commands, second one fails" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!'
  assert_success
  assert_log_equals RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN "failing_function foo bar baz" \
    ERROR 'failing_function foo bar baz (exit status 127)' \
    RUN "echo Goodbye, World!" \
    "Goodbye, World!"
}

@test "$SUITE: log multiple commands, second one fails in critical section" {
  run_log_script 'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!' \
    '@go.critical_section_end'
  assert_failure
  assert_log_equals RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN "failing_function foo bar baz" \
    FATAL 'failing_function foo bar baz (exit status 127)'
}

@test "$SUITE: log multiple commands without executing during dry run" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    'failing_function() { return 127; }' \
    '@go.log_command echo Hello, World!' \
    '@go.log_command failing_function foo bar baz' \
    '@go.log_command echo Goodbye, World!'
  run env _GO_DRY_RUN=true "$TEST_GO_SCRIPT"
  assert_success
  assert_log_equals RUN 'echo Hello, World!' \
    RUN "failing_function foo bar baz" \
    RUN 'echo Goodbye, World!'
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
  assert_log_equals RUN 'critical_subsection Hello, World!' \
    RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN 'failing_function foo bar baz' \
    ERROR 'failing_function foo bar baz (exit status 127)' \
    RUN 'echo We made it!' \
    'We made it!'
}

@test "$SUITE: nested critical sections dry run" {
  # Note that `echo Hello, World!` inside `critical_subsection` isn't logged,
  # since `critical_subsection` is only logged but not executed.
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
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
  run env _GO_DRY_RUN=true "$TEST_GO_SCRIPT"
  assert_success
  assert_log_equals RUN 'critical_subsection Hello, World!' \
    RUN 'failing_function foo bar baz' \
    RUN 'echo We made it!'
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
  assert_log_equals RUN 'critical_subsection Hello, World!' \
    RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN 'failing_function foo bar baz' \
    FATAL 'failing_function foo bar baz (exit status 127)'
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
  assert_log_equals RUN 'echo Hello, World!' \
    'Hello, World!' \
    RUN 'failing_function foo bar baz' \
    ERROR 'failing_function foo bar baz (exit status 127)' \
    RUN 'failing_function foo bar baz' \
    FATAL 'failing_function foo bar baz (exit status 127)'
}

@test "$SUITE: log and run command script using @go" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    '@go.log_command @go project-command-script "$@"'

  create_test_command_script 'project-command-script' 'echo $*'

  run test-go Hello, World!
  assert_success
  assert_log_equals RUN 'test-go project-command-script Hello, World!' \
    'Hello, World!'
}

@test "$SUITE: critical section in parent script applies to @go script" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    '@go.critical_section_begin' \
    '@go.log_command @go project-command-script "$@"' \
    '@go.critical_section_end' \
    '@go.log_command Should not get this far.'

  create_test_command_script 'project-command-script' \
    'failing_function() { return 127; }' \
    '@go.log_command failing_function "$@"'

  run test-go foo bar baz
  assert_failure
  assert_log_equals RUN 'test-go project-command-script foo bar baz' \
    RUN 'failing_function foo bar baz' \
    FATAL 'failing_function foo bar baz (exit status 127)'
}

@test "$SUITE: critical section in command script applies to parent script" {
  create_test_go_script ". \"\$_GO_USE_MODULES\" 'log'" \
    '@go.log_command @go project-command-script "$@"' \
    '@go.log_command Should not get this far.'

  create_test_command_script 'project-command-script' \
    'failing_function() { return 127; }' \
    '@go.critical_section_begin' \
    '@go.log_command failing_function "$@"' \
    '@go.critical_section_end'

  run test-go foo bar baz
  assert_failure
  assert_log_equals RUN 'test-go project-command-script foo bar baz' \
    RUN 'failing_function foo bar baz' \
    FATAL 'failing_function foo bar baz (exit status 127)'
}
