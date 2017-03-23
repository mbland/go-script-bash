# go-script-bash v1.4.0

This release contains some major improvements, including an O(5.3-18x) Bats test performance improvement, the new `lib/bats-main` and other testing library updates, the `go-template` bootstrap script, `_GO_STANDALONE` mode, improved `_GO_USE_MODULES` semantics, the new `get` and `new` commands, npm-like plugin semantics, and more.

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

All of the issues and pull requests for this release are visible in the [v1.4.0 milestone][].

[v1.4.0 milestone]: https://github.com/mbland/go-script-bash/milestone/2?closed=1

### Bats test suite performance improvement

Insight into how Bats captures stack trace information led to several rounds of performance optimizations to remove subshells and other child processes that resulted in a massive improvement. All the times below were measured on a MacBook Pro with a 2.9GHz Intel Core i5 CPU and 8GB 1867MHz DDR3 RAM.

The first round of improvements, to the go-script-bash framework itself, took the existing test suite running under Bash 3.2.57(1)-release from macOS 10.12 from O(7-8m) down to O(3m). As part of this process, the `set "$BATS_ASSERTION_DISABLE_SHELL_OPTIONS"` and `return_from_bats_assertion` mechanisms previously from `lib/bats/assertions` have been generalized as `set "$DISABLE_BATS_SHELL_OPTIONS` and `restore_bats_shell_options` in the new `lib/bats/helper-function` module.

After the first round of optimizations to the Bats framework itself, this time came down to O(1m25s). After the second round of Bats optimizations, the time came down to O(1m19s), for a total approximate speedup between 5.3x and 6x.

On Windows, the improvement is even more dramatic, given [forking new processes on Windows is apparently over 50x more expensive than on UNIX][win-fork]. Running under VMWare Fusion (versions 8.5.3 to 8.5.5), the same go-script-bash test suite went from O(50m-60m) down to O(20+m) after the go-script-bash optimizations, down to O(3m40s-6m20s) after the first round of Bats optimizations, and down to O(3m21s-5m25s) after the second round of Bats optimizations, for a total approximate speedup between 9x and 18x. (Possibly more, but I don't want to spend the time getting the old numbers for an exact calculation!)

[win-fork]: https://rufflewind.com/2014-08-23/windows-bash-slow

For more details, see the following artifacts:

* [mbland/go-script-bash#79: Consider refactoring Bats to avoid pipelines, subshells #79](https://github.com/mbland/go-script-bash/issues/79)
* [mbland/go-script-bash#156: Extract `lib/bats/function` from `lib/bats/assertions`](https://github.com/mbland/go-script-bash/issues/156)
* [The `lib/bats/helper-function` library](https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/bats/helper-function)
* [The `optimized-20170205` tag comment from mbland/bats](https://github.com/mbland/bats/releases/tag/optimized-20170205)
* [The `optimized-20170317` tag comment from mbland/bats](https://github.com/mbland/bats/releases/tag/optimized-20170317)
* [sstephenson/bats#210: Fix macOS/Bash 3.2 breakage; eliminate subshells from exec-test, preprocess](https://github.com/sstephenson/bats/pull/210)
* [mbland's comment on sstephenson/bats#150: Call for Maintainers](https://github.com/sstephenson/bats/issues/150#issuecomment-280382449)

### `lib/bats-main` test script library

To make it easier to write `./go test` commands with the same interface as that of the core library's `./go test` command—including test coverage reports via [kcov][] and [Coveralls][]—the `lib/bats-main` library has been extracted from the core library's `./go test` script. It contains many user-overrideable variables, but basic usage is straightforward. See the header comments from [lib/bats-main][] and the implementation of [`./go test`][] for details.

[kcov]:          https://github.com/SimonKagstrom/kcov
[coveralls]:     https://coveralls.io/
[lib/bats-main]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/bats-main
[go-test]:       https://github.com/mbland/go-script-bash/tree/v1.4.0/scripts/test

Also, Bats is no longer integrated into the repository as a submodule. Instead, `@go.bats_main` calls `@go.bats_clone` to create a shallow clone of a Bats repository, configured via the `_GO_BATS_DIR`, `_GO_BATS_URL`, and `_GO_BATS_VERSION` variables. (`@go.bats_clone` uses the new `@go get` command, described below, to create the clone.) By default, these variables are configured to clone [the optimized Bats from `mbland/bats`][mbland/bats opt].

[mbland/bats opt]: https://github.com/mbland/bats/releases/tag/optimized-20170317

### Testing library enhancements

In addition to the test/Bats optimizations and the new `lib/bats-main` library, other new test library features include:

* A completely new [lib/testing/stubbing][] library that uses the new `_GO_INJECT_SCRIPT_PATH` and `_GO_INJECT_MODULE_PATH` mechanism to stub core library scripts and modules, rather than the much riskier former implementation. ([#118][], [#121][]) See the sections below on "Improved command script search and `_GO_USE_MODULES` semantics" and "npm-like plugin semantics", as well as `./go help commands` and `./go modules -h` for further details.
* The `@go.test_compgen` helper function from [lib/testing/environment][] makes it easier to generate expected tab completion results, and fails loudly to prevent test setup errors.
* `stub_program_in_path` from [lib/bats/helpers][] now works for testing in-process functions (as opposed to running scripts), and `restore_program_in_path` has been added to help with cleanup and to guard against errors when stubbed program names are mistyped.
* See the previous section on test suite optimization for information about the new [lib/bats/helper-function][] library, which contains a mechanism for making Bats test helper functions run as quickly as possible and for pinpointing assertion failures. It works by temporarily disabling function tracing and `DEBUG` traps set by Bats to collect and display stack trace information.

[lib/testing/stubbing]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/testing/stubbing
[#118]: https://github.com/mbland/go-script-bash/issues/118
[#121]: https://github.com/mbland/go-script-bash/issues/121
[lib/testing/environment]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/testing/environment
[lib/bats/helpers]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/bats/helpers
[lib/bats/helper-function]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/bats/helper-function

### `go-template` bootstrap script

The new `go-template` file provides the boilerplate for a standard project `./go` script. Basically, copying this script into your project and running it is all you need to do to get started using the go-script-bash framework right away, as it will take care of cloning the `go-script-bash` framework into your project without the need to add it as a Git submodule. It contains several configuration variables, and any other project or application logic may be added to it as needed.

See the ["How to use this framework" section of the README][go-howto] and the comments from [go-template][] for details.

[go-howto]:    https://github.com/mbland/go-script-bash/tree/v1.4.0/README.md#how-to-use-this-framework
[go-template]: https://github.com/mbland/go-script-bash/tree/v1.4.0/go-template

### `_GO_STANDALONE` mode

The `_GO_STANDALONE` variable, when set, enables "Standalone" mode, whereby a `./go` script acts as an arbitrary application program rather than a project management script. In fact, a standalone application program can have its own project management `./go` script in the same repository.

See the ["Standalone mode" section of the README][standalone mode] for more
information.

[standalone mode]: https://github.com/mbland/go-script-bash/tree/v1.4.0/README.md#standalone-mode

### Improved command script search and `_GO_USE_MODULES` semantics

The command script search and `. "$_GO_USE_MODULES"` library module importation mechanism now implement the following precedence rules:

* `_GO_INJECT_SEARCH_PATH` and `_GO_INJECT_MODULE_PATH` for stubs injected during testing
* `_GO_CORE_DIR/libexec` and `_GO_CORE_DIR/lib` for core library command scripts
  and modules
* `_GO_SCRIPTS_DIR` and `_GO_SCRIPTS_DIR/lib` for command scripts and project-internal modules
* `_GO_ROOTDIR/lib` for publicly-exported modules (if the project is a go-script-bash plugin)
* `_GO_SCRIPTS_DIR/plugins/*/{bin,lib}` for command scripts and library modules from installed plugins
* Parent plugin dirs up to `_GO_PLUGINS_DIR/*/{bin,lib}` for plugin command scripts and library modules

This reflects a more natural, predictable search order, and the `. "$_GO_USE_MODULES"` mechanism now pinpoints potential module import collisions with a verbose warning message. See `./go help commands` and `./go modules -h` for more details.

### New commands: `get` and `new`

The `./go get file` command makes it easy to fetch a single file over the network using `curl`, `wget`, or FreeBSD's `fetch`, and `./go get git-repo` creates a shallow clone of a Git repository (notably used by the `lib/bats-main` and `lib/kcov-ubuntu` libraries).

The `./go new` command makes it easy to create a new command script (`--command`), internal library module (`--internal`), public library module (`--public`), or Bats test file (`--test`), with minimal boilerplate. It can also create any other arbitrary file via the `--type` option, so that users can reuse the command to generate their own boilerplate files and benefit from the same safety checks, error reporting, and automatic `EDITOR` opening.

See `./go help get` and `./go help new` for more information.

### npm-like plugin semantics

The pull requests associated with [#120][] implement a new plugin protocol very similar to [the `node_modules` search mechanism implemented by npm][n_m]. The new `@go.search_plugins` function from `go-core.bash` implements this algorithm, and is used by `. "$_GO_USE_MODULES"` and the logic that builds the command script search paths. See `./go help plugins` and the comments for `@go.search_plugins` for more details.

[#120]: https://github.com/mbland/go-script-bash/issues/120
[n_m]:  https://docs.npmjs.com/files/folders#cycles-conflicts-and-folder-parsimony

A forthcoming release will add documentation and tooling to make it easier to work with plugins.

### `@go.select_option` and demo

The `@go.select_option` function added to `go-core.bash` in [#141][] makes it easy to write interactive prompts for the user to select an item from a list of options. Run `./go demo-core select-option` to see it in action.

[#141]: https://github.com/mbland/go-script-bash/pull/141

### Various bug fixes

* Tab completion no longer changes the current directory ([#124][]; thanks to [@jeffkole][] for reporting in [#123][]).
* `@go.printf` no longer adds a newline unconditionally, and no longer harbors a latent infinite loop bug ([#146][], [#149][]).
* `stub_program_in_path` from [lib/bats/helpers][] now avoids calling the program it's trying to stub by generating the stub _before_ setting `PATH` and calling `hash` ([#168][]).

[#124]: https://github.com/mbland/go-script-bash/pull/124
[@jeffkole]: https://github.com/jeffkole
[#123]: https://github.com/mbland/go-script-bash/pull/123
[#146]: https://github.com/mbland/go-script-bash/pull/146
[#149]: https://github.com/mbland/go-script-bash/pull/149
[lib/bats/helpers]: https://github.com/mbland/go-script-bash/tree/v1.4.0/lib/bats/helpers
[#168]: https://github.com/mbland/go-script-bash/pull/168

## Changes since v1.3.0

You can see the details of every change by issuing one or more of the following commands after cloning: https://github.com/mbland/go-script-bash

<pre>
$ ./go changes v1.3.0 v1.4.0
$ gitk v1.3.0..HEAD
</pre>
