# go-script-bash v1.1.0

This release adds some major new features, two new builtin commands, and multiple bug fixes and internal improvements.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

### Modules

You can import optional Bash library code from the core framework, third-party plugins, or your own project's scripts directory by sourcing the `_GO_USE_MODULES` script. See the **Modules** section of the README or run `./go help modules` and `./go modules --help` for more information.

### Logging

The core library `log` module provides functions for standard logging facilities. For more information, see the **Logging** section from the README and run `./go modules --help log`.

### Bats test assertions and helpers

The assertions and helpers from the test suite have been extracted into the `lib/bats/assertions` and `lib/bats/helpers` libraries. See the **Bats test assertions and helpers** section from the README and read the comments from each file for more information.

### `kcov-ubuntu` module for test coverage on Linux

The `kcov-ubuntu` module provides the `run_kcov` function that uses [kcov](https://github.com/SimonKagstrom/kcov) to collect test coverage on Ubuntu Linux. See the **`kcov-ubuntu` module for test coverage on Linux** section of the README and run `./go modules --help kcov-ubuntu` for more information.

### Exported `_GO_*` variables and the `vars` builtin command

A number of global variables starting with the prefix `_GO_*` are exported as environment variables and are available to command scripts in all languages. See the **Command script API** section from the README and run `./go help vars` for more information.

## Changes since v1.0.0

<pre>
9411a89 Mike Bland <mbland@acm.org>
        Merge pull request #23 from mbland/version

e8ef35b Mike Bland <mbland@acm.org>
        core: Introduce _GO_CORE_VERSION

17a69d2 Mike Bland <mbland@acm.org>
        Add documentation improvements for v1.1.0 release

ecd2d81 Mike Bland <mbland@acm.org>
        use: Unset correct variable

006c38b Mike Bland <mbland@acm.org>
        Merge pull request #22 from mbland/remove-stale-files

e17c181 Mike Bland <mbland@acm.org>
        Remove old test `./go` scripts

f9675e5 Mike Bland <mbland@acm.org>
        Merge pull request #21 from mbland/plugins

33c54b6 Mike Bland <mbland@acm.org>
        plugins: Revert changes from #20

ce20155 Mike Bland <mbland@acm.org>
        Merge pull request #20 from mbland/vars

6b376eb Mike Bland <mbland@acm.org>
        vars: Make test array quotifying more robust

241d2c7 Mike Bland <mbland@acm.org>
        Revamp `_GO_*` var exports, add `vars` builtin

7c1123b Mike Bland <mbland@acm.org>
        Move all _GO_* vars to core and document them

17beb1e Mike Bland <mbland@acm.org>
        Merge pull request #19 from mbland/assert-lines-equal

70d546f Mike Bland <mbland@acm.org>
        assertions: Add assert_lines_equal

32d47fc Mike Bland <mbland@acm.org>
        changes: Don't add `^` to end ref

580f08d Mike Bland <mbland@acm.org>
        core: Tweak COLUMNS test slightly

47b6e63 Mike Bland <mbland@acm.org>
        Merge pull request #18 from mbland/columns

5292839 Mike Bland <mbland@acm.org>
        core: Fix test for OS X on Travis without /dev/tty

c7ee892 Mike Bland <mbland@acm.org>
        core: Reproduce and fix `tput cols` error from #17

664a51f Mike Bland <mbland@acm.org>
        Merge pull request #17 from mbland/columns

5bdbd2c Mike Bland <mbland@acm.org>
        core: Update how COLUMNS is set

5fc49a5 Mike Bland <mbland@acm.org>
        log: Skip setup-project test case on MSYS2

0e91281 Mike Bland <mbland@acm.org>
        Merge pull request #16 from mbland/log-setup

ecb6b83 Mike Bland <mbland@acm.org>
        log: Fix @go.critical_section_end return bug

b7f7699 Mike Bland <mbland@acm.org>
        log: Add @go.setup_project function

ed05f2b Mike Bland <mbland@acm.org>
        Merge pull request #15 from mbland/log-command

da20203 Mike Bland <mbland@acm.org>
        log: Add log_command tests for @go command cases

db79ba1 Mike Bland <mbland@acm.org>
        log: Add @go.log_command, critical section flag

43fae60 Mike Bland <mbland@acm.org>
        Merge pull request #14 from mbland/add-or-update-log-level

949fb32 Mike Bland <mbland@acm.org>
        log: Implement @go.add_or_update_log_level

dd712c6 Mike Bland <mbland@acm.org>
        Merge pull request #13 from mbland/log

0a7bc5e Mike Bland <mbland@acm.org>
        lib/log: Add logging module

31a1d30 Mike Bland <mbland@acm.org>
        complete: Fix typo in internal library comment

3cc22b0 Mike Bland <mbland@acm.org>
        Merge pull request #12 from mbland/assertions

0d94845 Mike Bland <mbland@acm.org>
        Revert previous two commits

f4a0f85 Mike Bland <mbland@acm.org>
        assertions: Reset return trap when trap exits

7ca3d05 Mike Bland <mbland@acm.org>
        assertions: Introduce bats_assertion_return_trap

40d6218 Mike Bland <mbland@acm.org>
        assertions: Make public return_from_bats_assertion

87bb07c Mike Bland <mbland@acm.org>
        assertions: Reproduce and fix latent functrace bug

52bc541 Mike Bland <mbland@acm.org>
        Merge pull request #11 from mbland/complete

112e046 Mike Bland <mbland@acm.org>
        env/bash: Put single quotes around unset argument

e7f02fe Mike Bland <mbland@acm.org>
        complete: Eliminate compgen from internal library

096f0f3 Mike Bland <mbland@acm.org>
        bats/assertions: Change double quotes to single

d8e4231 Mike Bland <mbland@acm.org>
        complete: Replace most compgen calls with echo

4d61457 Mike Bland <mbland@acm.org>
        complete: Switch all tests to use ./go complete

54e8e9a Mike Bland <mbland@acm.org>
        Merge pull request #10 from mbland/tput-fix-test-docs

e779deb Mike Bland <mbland@acm.org>
        test: Expand comments, refactor slightly

b9792bf Mike Bland <mbland@acm.org>
        kcov-ubuntu: Update run_kcov function comment

4c66893 Mike Bland <mbland@acm.org>
        core: Undo tput error redirect

676dd18 Mike Bland <mbland@acm.org>
        Merge pull request #9 from mbland/bats-libs

69fb63b Mike Bland <mbland@acm.org>
        bats/assertions: Reorder functions, add docs

d692bb9 Mike Bland <mbland@acm.org>
        bats/assertions: Add optional fail() reason, docs

ac8ed3f Mike Bland <mbland@acm.org>
        tests: Extract public bats/assertions module

2707493 Mike Bland <mbland@acm.org>
        tests: Consolidate environment.bash

c77932e Mike Bland <mbland@acm.org>
        kcov: Convert to public kcov-ubuntu module

1a47920 Mike Bland <mbland@acm.org>
        cmd-desc: Remove create_test_command_script calls

3deee25 Mike Bland <mbland@acm.org>
        run-cmd: Update _GO_* var tests to run subcommands

4168b58 Mike Bland <mbland@acm.org>
        Extract public bats/helpers module

87ce40a Mike Bland <mbland@acm.org>
        Merge pull request #8 from mbland/cmd-name-argv

202b17c Mike Bland <mbland@acm.org>
        core: Export _GO_CMD_{NAME,ARGV}, add Bash test

d674191 Mike Bland <mbland@acm.org>
        Merge pull request #7 from mbland/cmd-desc

9bd1524 Mike Bland <mbland@acm.org>
        core: Default to 80 columns on all tput errors

47d9476 Mike Bland <mbland@acm.org>
        TEMP: Print value of $TERM to debug Travis issue

271c726 Mike Bland <mbland@acm.org>
        core: Check $TERM before setting columns with tput

c1ba9c8 Mike Bland <mbland@acm.org>
        cmd_desc: Show full command names in descriptions

c2098c4 Mike Bland <mbland@acm.org>
        Merge pull request #6 from mbland/core-updates

2777ca8 Mike Bland <mbland@acm.org>
        core: Export variables for non-Bash script access

1158bc7 Mike Bland <mbland@acm.org>
        core: Escape % when only one @go.printf argument

995daf0 Mike Bland <mbland@acm.org>
        script_helper: Default to bash, allow other langs

6444f51 Mike Bland <mbland@acm.org>
        Merge pull request #5 from mbland/modules-builtin

0a4886a Mike Bland <mbland@acm.org>
        README: ./go modules help => ./go modules --help

78c447a Mike Bland <mbland@acm.org>
        test, modules: Quote $_GO_USE_MODULES, add docs

9bb7a45 Mike Bland <mbland@acm.org>
        Add modules builtin command

766a354 Mike Bland <mbland@acm.org>
        command_descriptions: Trim trailing whitespace

e764723 Mike Bland <mbland@acm.org>
        command_descriptions: Return error if read fails

7cd5dd5 Mike Bland <mbland@acm.org>
        kcov: Add note explaining 2>/dev/null redirection

80b7abe Mike Bland <mbland@acm.org>
        test: Use time builtin

4c8f931 Mike Bland <mbland@acm.org>
        complete: Add public module, completion removal

97fd0df Mike Bland <mbland@acm.org>
        test/script_helper: Add TEST_GO_PLUGINS_DIR

2d88f57 Mike Bland <mbland@acm.org>
        format: Add public module, pad and zip functions

8c23dcd Mike Bland <mbland@acm.org>
        Merge pull request #3 from mbland/lightning-talk

4f1e6c6 Mike Bland <mbland@acm.org>
        README: Update location of lib/internal/env

515730d Mike Bland <mbland@acm.org>
        README: Add link to Surge 2016 lightning talk

2cbfdda Mike Bland <mbland@acm.org>
        Merge pull request #2 from mbland/use-modules

a5973af Mike Bland <mbland@acm.org>
        use: Fix test for bash < 4.4

55d09f9 Mike Bland <mbland@acm.org>
        test: Replace direct source with _GO_USE_MODULES

ed78d9f Mike Bland <mbland@acm.org>
        core: Add _GO_USE_MODULES for optional modules

2d5cb96 Mike Bland <mbland@acm.org>
        Merge pull request #1 from mbland/refactor

345dd55 Mike Bland <mbland@acm.org>
        Lowercase __go_orig_dir, unset temp globals

e6c29fd Mike Bland <mbland@acm.org>
        Move all lib/ files to lib/internal/

1634d85 Mike Bland <mbland@acm.org>
        core: Refactor, update comments
</pre>
