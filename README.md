## The `./go` script: a unified development environment interface

[![Continuous integration status](https://travis-ci.org/mbland/go-script-bash.png?branch=master)](https://travis-ci.org/mbland/go-script-bash)
[![Coverage Status](https://coveralls.io/repos/github/mbland/go-script-bash/badge.svg?branch=master)](https://coveralls.io/github/mbland/go-script-bash?branch=master)

A `./go` script aims to abstract away many of the steps needed to develop (and
sometimes deploy) a software project. It is a replacement for READMEs and
other documents that may become out-of-date, and when maintained properly,
should provide a cohesive and discoverable interface for common project tasks.

This framework was inspired by:

- "In Praise of the ./go Script: Parts I and II" by Pete Hodgson
  - https://www.thoughtworks.com/insights/blog/praise-go-script-part-i
  - https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii
- rbenv: https://github.com/rbenv/rbenv

**Note:** Not to be confused with the [Go programming
language](https://golang.org). This convention is completely unrelated,
though it does bear a great deal of resemblance to the Go language's `go`
command.

### Table of contents

- [Environment setup](#environment-setup)
- [How to use this framework](#how-to-use-this-framework)
- [Feedback and contributions](#feedback-and-contributions)
- [Installing Bash](#installing-bash)
- [Open Source](#open-source)
- [Prior work](#prior-work)

### Environment setup

To run a `./go` script that uses this module, or to add it to your own project,
you must have [Bash](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29)
version 3.2 or greater installed on your system. Run `bash --version` to make
sure Bash is in your `PATH` and is a compatible version. You should see output
like this:

```
GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin15)
Copyright (C) 2007 Free Software Foundation, Inc.
```

If you do not see this, follow the instructions in the [Installing
Bash](#installing-bash) section later in this document.

__Note: While Bash is required to run this framework, your individual command
scripts can be in any other interpreted language.__

### How to use this framework

First you'll need a copy of this framework available in your project sources.
Archives are available at:

- https://github.com/mbland/go-script-bash/archive/v0.0.0.tar.gz
- https://github.com/mbland/go-script-bash/archive/v0.0.0.zip

You can also add this repository to your project as a [`Git
submodule`](https://git-scm.com/book/en/v2/Git-Tools-Submodules):

```bash
$ git submodule add https://github.com/mbland/go-script-bash <target-dir>
$ git commit -m 'Add go-script-bash framework'
$ git submodule update --init
```

where `<target-dir>` is any point inside your project directory structure that
you prefer.

Then create a bash script in the root directory of your project to act as the
main `./go` script. This script need not be named `go`, but it must contain the
following as the first and last executable lines, respectively:

```bash
. "${0%/*}/go-core.bash" "scripts"
@go "$@"
```

where:
- `"${0%/*}"` produces the path to the project's root directory
- `go-core.bash` is the path to the file of the same name imported from this
repository
- `scripts` is the path to the directory holding your project's command scripts
  relative to the project root

#### Directory structure

The `./go` script changes to the project root directory before executing any
commands. That means every command script you write will also run within the
project root directory, so every relative file and directory path will be
interpreted as relative to the project root.

Your project structure may look something like this:

```
project/
  go - main go script
  scripts/ - project scripts
    plugins/ - (optional) third-party command scripts (see `./go help plugins`)
    go-script-bash/
      go-core.bash - top-level functions
      lib/ - utility functions
      libexec/ - builtin subcommands
```

This structure implies that the first line of your `./go` script will be:
```bash
. "${0%/*}/scripts/go-script-bash/go-core.bash" "scripts/bin"
```

The precedence for discovering commands is:

- aliases/builtins (provided by this framework)
- plugins (in `scripts/plugins` above)
- project scripts (in `scripts` above)

#### Command scripts

Each command script for your project residing in the `scripts` directory must
adhere to the following conditions:

- No filename extensions.
- It must be executable, with a `#!` (a.k.a. "she-bang") line. The interpreter
  name will be parsed from this line, whether it is an absolute path
  (`#!/bin/bash`) or is of the form: `#!/usr/bin/env bash`.
- If `scripts/parent` is a command script, subcommand scripts must reside within
  a directory named: `scripts/parent.d`.

__Scripts can use any interpreted language available on the host system; they
need not be written in Bash.__ Bash scripts will be sourced (i.e. imported into
the same process running the `./go` script itself). Other languages will use the
`PATH` environment variable to discover the interpreter for the script.

#### Command summaries and help text

The builtin `./go help` command will parse command script summaries and help
text from the header comment block of each script. Run `./go help help` to learn
more about the formatting rules.

#### Tab completion

By evaluating the value of `./go env -` within your shell, all builtin commands
and aliases provide automatic tab completion of file, directory, and other
arguments. If an implementation isn't available for your shell (within
`lib/env/`), it's very easy to add one. Feel free to open an issue or, better
yet, [send a pull request](#feedback-and-contributions)!

To learn the API for adding tab completion to your own command scripts, run
`./go help complete`. You can also learn by reading the scripts for the builtin
commands.

#### Including common code

There are a number of possible methods available for sharing code between
command scripts. Some possibilities are:

- Include common code and constants in the top-level `./go` script, after
  sourcing `go-core.bash` and before calling `@go`.
- Source a file in the same directory that isn't executable.
- Source a file in a child directory that may not have a name of the form:
  `parent.d`.
- Source files from a dedicated directory relative to `$_GO_ROOTDIR`, e.g.:
  ```bash
  . "path/to/lib/common.sh"
  ```
- Subcommand scripts can source the parent command via:
  ```bash
  . "${BASH_SOURCE[0]%.d/*}"
  ```

#### Command script API

Any script in any language can invoke other command scripts by running
`./go <command> [args..]`. In Bash, however, you can also invoke the `@go`
function directly as `@go <command> [args...]`.

The `@go` and `@go.printf` functions are available to command scripts written in
Bash, as Bash command scripts are sourced rather than run using another language
interpreter.

The `_GO_ROOTDIR`, `_GO_SCRIPT`, and `COLUMNS` environment variables are
exported and available to scripts in all languages.

#### Plugins

You can add third-party plugin command scripts to the `plugins` subdirectory of
your scripts directory. Run `./go help plugins` for more information.

### Feedback and contributions

Feel free to [comment on or file a new GitHub
issue](https://github.com/mbland/go-script-bash/issues) or otherwise ping
[@mbland](https://github.com/mbland) with any questions or comments you may
have, especially if the current documentation hasn't addressed your needs.

If you'd care to contribute to this project, be it code fixes, documentation
updates, or new features, please read the [CONTRIBUTING](CONTRIBUTING.md) file.

### Installing Bash

If you're using a flavor of UNIX (e.g. Linux, OS X), you likely already have a
suitable version of Bash already installed and available. If not, use your
system's package manager to install it.

On Windows, the [Git for Windows](https://git-scm.com/downloads),
[MSYS2](https://msys2.github.io/) and [Cygwin](https://www.cygwin.com/)
distributions all ship with a version of Bash. On Windows 10, you can also use
the [Windows Subsystem for
Linux](https://msdn.microsoft.com/en-us/commandline/wsl/about).

#### Updating your `PATH` environment variable

Once you've installed `bash`, your `PATH` environment variable must include
its installation directory. On UNIX, you can add it in the appropriate
initialization file for your shell; look up your shell documentation for details.

On Windows, in most cases, you'll use the terminal program that ships with Git
for Windows, MSYS2, or Cygwin, or you'll invoke the Windows System for Linux
environment by entering `bash` in a built-in Command Prompt window. These
terminals automatically set `PATH` so that Bash is available.

However, if you want to use the Git, MSYS2, or Cygwin `bash` from the built-in
Command Prompt window, open the **Start** menu and navigate to **Windows
System > Control Panel > System and Security > System > Advanced system
settings**. Click the **Environment Variables...** button, select `PATH`, and
add the directory containing your `bash` installation. The likely paths for each
environment are:

- Git: `C:\Program Files\Git\usr\bin\`
- MSYS2: `C:\msys64\usr\bin\`
- Cygwin: `C:\cygwin64\bin\`

To use one of these paths temporarily within a Command Prompt window, you can
run the following:

```
C:\path\to\my\go-script-bash> set PATH=C:\Program Files\Git\usr\bin\;%PATH%

# To verify:
C:\path\to\my\go-script-bash> echo %PATH%
C:\path\to\my\go-script-bash> where bash

# To run the tests:
C:\path\to\my\go-script-bash> bash ./go test
```

It should not be necessary to set Bash as your default shell. On Windows,
however, you may wish to execute the `bash` command to run it as your shell
before executing the `./go` script or any other Bash scripts, to avoid having to
run it as `bash ./go` every time.

#### Recommended utilities

The framework as-is does not require any other external tools. However, in order
for the automatic command help and output formatting to work, you'll need the
following utilities installed:

- `fold` (coreutils)
- `tput` (ncurses) on Linux, OS X, UNIX; `mode.com` should be present on Windows

### Open Source License

This software is made available as [Open Source
software](https://opensource.org/osd-annotated) under the [ISC
License](https://www.isc.org/downloads/software-support-policy/isc-license/).
For the text of the license, see the [LICENSE](LICENSE.md) file.

### Prior work

This is a Bash-based alternative to the
[18F/go_script](https://github.com/18F/go_script) Ruby implementation.
