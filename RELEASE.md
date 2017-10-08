# go-script-bash v1.7.0

This is a minor update to add a few test helpers, `_GO_PLATFORM` variables and the `./go goinfo` command, several file system processing modules, and a handful of project improvements.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I][hodg-1] and [Part II][hodg-2].

[hodg-1]: https://www.thoughtworks.com/insights/blog/praise-go-script-part-i
[hodg-2]: https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii

**Note:** The `./go` script concept is completely unrelated to the [Go programming language][golang], though [the Go language's `go` command][golang-cmd] encapsulates many common project functions in a similar fashion.

[golang]:     https://golang.org
[golang-cmd]: https://golang.org/cmd/go/

This software is made available as [Open Source software][oss-def] under the [ISC License][]. If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

[oss-def]:     https://opensource.org/osd-annotated
[isc license]: https://www.isc.org/downloads/software-support-policy/isc-license/

## What's new in this release

All of the issues and pull requests for this release are visible in the [v1.7.0 milestone][].

[v1.7.0 milestone]: https://github.com/mbland/go-script-bash/milestone/5?closed=1

### `./go null`

The `./go null` command verifies that the framework is installed and functioning properly (#190).

### New test helpers

There are a few powerful new test helper functions:

* `create_forwarding_script` (#192, #195): Used to create a wrapper in `BATS_TEST_BINDIR` to make a system program accessible while restricting `PATH` via `PATH="$BATS_TEST_BINDIR"`.
* `restore_programs_in_path` (#196): Allows a single call to remove multiple command stub scripts.
* `run_test_script` (#196): Creates and runs a test script in one step, so that create_bats_test_script and run need not be called separately.
* `run_bats_test_suite` (#196): A specialized version of `run_test_script` specifically for generating and running Bats test cases.
* `run_bats_test_suite_in_isolation` (#196): An even more specialized version of `run_bats_test_suite` to ensure that `PATH` is restricted to `BATS_TEST_BINDIR` and the Bats `libexec/` directory within the suite.
* `lib/bats/background-process` (#197): Helpers for managing and validating background processes.
* `skip_if_none_present_on_system` (#198): Skips a test if none of the specified system programs are available.

### `_GO_PLATFORM` vars and `./go goinfo` command

The `lib/platform` module introduced in #200 provides an interface to detect on which system the script is running. Is parses [/etc/os-release][os-release] if it's available; otherwise uses `OSTYPE`, `uname -r`, and `sw_vers -productVersion` (on macOS).

[os-release]: https://www.freedesktop.org/software/systemd/man/os-release.html

The `./go goinfo` command introduced in #216 uses the `lib/platform` module to print version information about the go-script-bash framework, Bash, and the host operating system:

```bash
$ ./go goinfo

_GO_CORE_VERSION:         v1.7.0
BASH_VERSION:             4.4.12(1)-release
OSTYPE:                   darwin16.3.0
_GO_PLATFORM_ID:          macos
_GO_PLATFORM_VERSION_ID:  10.13
```

### File system processing modules

Introduced in #201, `@go.native_file_path_or_url` from `lib/portability` converts a file system path or `file://` URL to a platform-native path. This is necessitated by MSYS2, especially Git for Windows, which has system programs which expect Windows-native paths as input, or whose output will reflect Windows-native paths. It's used in several tests, as well as the `./go get` command.

The `lib/path` module introduced in #203 and #206 includes functions to canonicalize file system paths, resolve symlinks, and walk directories.

`lib/fileutil` from #204 and updated in #207 and #210 contains functions to safely create directories (with extensive error reporting), to collect all the regular files within a directory structure, to safely copy all files into a new directory structure, and to safely mirror directories using `tar`.

`lib/diff` from #205 contains functions to log or edit differences between files and directory trees.

`lib/archive` from #211 contains the `@go.create_gzipped_tarball` convenience function to easily and safely create `.tar.gz` archive files.

### Project improvements

The project now contains a GitHub issue and pull request templates, a GitHub `CODEOWNERS` file, and an Appveyor build to ensure Windows compatibility. See:

* https://github.com/blog/2111-issue-and-pull-request-templates
* https://help.github.com/articles/helping-people-contribute-to-your-project/
* https://github.com/blog/2392-introducing-code-owners
* https://help.github.com/articles/about-codeowners/
* https://ci.appveyor.com/project/mbland/go-script-bash

### Bug fixes

* `stub_program_in_path` (#194): Now ensures that new stubs are passed to `hash`. Previously, if a command had already been invoked, Bash would remember its path, and ignore the new stub.

## Changes since v1.6.0

You can see the details of every change by issuing one or more of the following commands after cloning: https://github.com/mbland/go-script-bash

<pre>
$ ./go changes v1.6.0 v1.7.0
$ gitk v1.6.0..v1.7.0
</pre>
