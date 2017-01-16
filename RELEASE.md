# go-script-bash v1.3.0

This is a massive feature update that greatly extends the capabilities of the `log` module, improves existing test helpers and adds many new ones, adds several new modules available via `_GO_USE_MODULES`, plus much more. (And it goes without saying there are tons of bug fixes and compatibility workarounds!)

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

All of the issues and pull requests for this release are visible in the [v1.3.0 milestone](https://github.com/mbland/go-script-bash/milestone/1?closed=1). Many of the new features were inspired by the enthusiastic and thoughtful input from [John Omernik](https://github.com/JohnOmernik), based on his experience integrating the framework into his [JohnOmernik/zetago project](https://github.com/JohnOmernik/zetago).

### `lib/log` updates

`lib/log` gained a number of powerful new features in this update:

- Timestamp prefixes are available by defining `_GO_LOG_TIMESTAMP_FORMAT`.
- Each log level can now emit output to any arbitrary number of file descriptors by applying `@go.log_add_output_file`.
- `_GO_LOG_LEVEL_FILTER` and `_GO_LOG_CONSOLE_FILTER` help control the amount of information logged to files or to the console, respectively.
- The new lowest-priority `DEBUG` log level isn't emitted by default; use one of the above filters or `@go.log_add_output_file` to capture it.
- The new `QUIT` log level exits the process like `FATAL`, but without a stack trace.
- `@go.log_command` now captures all command output (even from subprocesses!) and emits it across all file descriptors configured for the `RUN` log level.
- `@go.critical_section_begin` now takes an argument to determine whether failing commands run under `@go.log_command` will log `QUIT` or `FATAL` upon error; the default is set by `_GO_CRITICAL_SECTION_DEFAULT`, which defaults to `FATAL`
- The new `demo-core log` builtin subcommand provides an interactive demonstration of `log` module features; see `./go help demo-core log`.
- Testing assertions and helper functions are publicly available in `lib/testing/log` and `lib/testing/stack-trace`.

See `./go modules -h log` for more information.

### New `lib/file` module for file descriptor-based file I/O

The new `lib/file` functions make it easy to open, write to, and close file descriptors in a safe and convenient fashion. While most of these functions support the new `lib/log` features, they are general-purpose and available to import via `. "$_GO_USE_MODULES" file`. See `./go modules -h file` for more information.

### New `lib/validation` file to validate caller-supplied data

The functions from `lib/validation` help make sure that caller-supplied data and variable names are well-formed and won't execute arbitrary code. The `*_or_die` variations will exit with a stack trace if an item violates validation constraints. Useful for examining identifiers before invoking `eval` or builtins such as `printf -v` that expect an identifier name as an argument. See `./go modules -h validation` for more information.

### Expanded and improved `lib/bats` module and the new `lib/testing` module for testing

It's now easier than ever to compose new assertions from `lib/bats/assertions`, thanks to the new `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"` and `return_from_bats_assertion` convention. New assertions are also easier to test thanks to the new `lib/bats/assertion-test-helpers` utilities.

`lib/bats/assertions` now contains:

- The `fail_if` assertion negator for `lib/bats/assertions` assertions, which makes it easy to write negative conditions with robust output
- The new `assert_lines_match` assertion
- `set_bats_output_and_lines_from_file`, which is used to implement the new `assert_file_equals`, `assert_file_matches`, and `assert_file_lines_match` assertions

Goodies now available in `lib/bats/helpers` include:

- `fs_missing_permission_support` and `skip_if_cannot_trigger_file_permission_failure` for skipping test cases on platforms that cannot trigger file permission-based conditions
- `test_join` for joining multiple expected output elements into a single variable
- `test_printf` and the `TEST_DEBUG` variable for producing targeted test debugging output
- `test_filter` and the `TEST_FILTER` variable for pinpointing specific test cases within a suite and skipping the rest
- `split_bats_output_into_lines` to ensure blank lines from `output` are preserved in `lines`; this facilitates using `assert_lines_equal` and `assert_lines_match` with output containing blank lines
- `stub_program_in_path` to easily write temporary test stubs for programs in `PATH`

Also, framework-specific test helpers have been exported to `lib/testing`, to help with writing tests that depend on core framework output and behavior, including functions that help validate stack trace and `@go.log` output.

All existing and new test helper functions have also been thoroughly tested on multiple platforms to ensure portability, ease-of-use, and a minimum of surprises.

### `lib/format` updates

The `lib/format` module gained two new functions:

- `@go.array_printf` for transforming an entire array of items at once using `printf -v`
- `@go.strip_formatting_codes` for removing ASCII formatting codes from a string, used by `@go.log` when writing to non-console file descriptors in the absence of `_GO_LOG_FORMATTING`

Also, `@go.pad_items` and `@go.zip_items` have updated interfaces that expect the caller to provide the name of the output variable, now that both are defined in terms of `@go.array_printf` (which is in turn implemented using the new `@go.split`, described below.) See `./go modules -h format` for more information.

### New `lib/strings` modules

The `lib/strings` module provides `@go.split` and `@go.join` functions that implement behavior common to other programming language libraries. See `./go modules -h strings` for more information.

`@go.split` in particular is highly recommend for widespread use to avoid an obscure Bash bug on Travis CI; see the function comments and `git show 99ab78 2297b4` for details.

### `_GO_USE_MODULES` exported for subprocess use

Now any Bash process spawned by the `./go` script has access to the `_GO_USE_MODULES` mechanism, most notably Bats test cases and assertions.

### New `demo-core` framework and `lib/subcommands` module

The `lib/subcommands` module exports the `@go.show_subcommands` function, which may be used to implement commands that are only shells for a number of subcommands. See `./go modules -h subcommands` for more information.

The new `demo-core` command demonstrates the use of `@go.show_subcommands`, and provides a framework for writing small demonstration programs for module features. As a first step, the `demo-core log` subcommand provides a demonstration of various `log` module features. See `./go help demo-core` and `./go help demo-core log` for more information.

### `@go.printf` works independently of `fold`

`@go.printf` no longer opens a pipe to the `fold` program, and now folds lines itself. The performance difference was a very minor improvement or degradation across systems, and now output is folded regardless of the presence of `fold` on the host system.

### Uses `[` instead of `[[` in all Bats test cases

Turns out there's a gotcha when using `[[` in Bats test cases under Bash versions lower than 4.1, such as the stock 3.2.57(1)-release that ships on macOS. See `git show fefce2` for details.

### Uses ASCII Unit Separator (`$'\x1f'`) instead of NUL to export arrays

Previously, `$'\0'` was used to export the `_GO_CMD_NAME` and `_GO_CMD_ARGV` arrays to commands written in other languages. However, it wasn't possible to successfully use NUL to implement the new `@go.array_printf` in the `lib/format` module, or to pass it as a delimiter to `@go.split` from the new `lib/strings` module, since Bash can join strings using `IFS=$'\0'`, but not split them. (Setting `IFS=$'\0'` is equivalent to setting it to the null string, which disables word splitting.) Consequently, the ASCII Unit Separator character seemed a fine substitute for that purpose, and it seemed wise to apply it to `_GO_CMD_NAME` and `_GO_CMD_ARGV` as well.

## Changes since v1.2.1

You can see the details of every change by issuing one or more of the following commands after cloning: https://github.com/mbland/go-script-bash

<pre>
$ ./go changes v1.2.1 v1.3.0
$ gitk v1.2.1..HEAD
</pre>
