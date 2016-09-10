## The `./go` script: a unified development environment interface

**WARNING: This is still in a pre-alpha state. I still need to flesh out the
docs, add some installation scripts, and add a lot more tests, now that
[exploration has given way to
settlement](https://github.com/mbland/unit-testing-node/blob/18f-pages/_pages/concepts/exploration-vision-and-settlement.md).
I've pushed this repo just to back up the work I've done so far.**

[![Build
status](https://travis-ci.org/mbland/go-script-bash.png?branch=master)](https://travis-ci.org/mbland/go-script-bash)

A `./go` script aims to abstract away all of the steps needed to develop (and
sometimes deploy) a software project. It is a replacement for READMEs and
other documents that may become out-of-date, and when maintained properly,
should provide a cohesive and discoverable interface for common project tasks.

This framework was inspired by:

- "In Praise of the ./go Script: Parts I and II" by Pete Hodgson
  https://www.thoughtworks.com/insights/blog/praise-go-script-part-i
  https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii
- rbenv: https://github.com/rbenv/rbenv

**Note:** Not to be confused with the [Go programming
language](https://golang.org). This convention is completely unrelated,
though it does bear a great deal of resemblance to the Go language's `go`
command.

### Table of contents

- [Environment setup](#environment-setup)
- [Feedback and contributions](#feedback-and-contributions)
- [Open Source](#open-source)
- [Prior work](#prior-work)

### Environment setup

To run a `./go` script that uses this module, or to add it to your own project,
you must have [Bash](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29)
version 3.1 or greater installed on your system. Run `bash --version` to make
sure Bash is in your `PATH` and is a compatible version. You should see output
like this:

```
GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin15)
Copyright (C) 2007 Free Software Foundation, Inc.
```

If Bash isn't already installed on your system:
- If you're using a flavor of UNIX (e.g. Linux, OS X), you likely already have a
  suitable version of Bash already installed and available. If not, use your
  system's package manager to install it.
- On Windows, install either [Minimalist GNU for Windows
  (MinGW)](http://www.mingw.org/) with the [MSYS
  utilities](http://www.mingw.org/wiki/MSYS), or
  [Cygwin](https://www.cygwin.com/). Other applications such as
  [Git](https://git-scm.com/downloads) may have installed a version as well.

Once you've installed `bash`, you must add its installation directory to your
`PATH` environment variable:
- On UNIX, you can add it in the appropriate initialization file for your
  shell; look up your shell documentation for details.
- On Windows, open the **Start** menu and navigate to **Windows System > Control
  Panel > System and Security > System > Advanced system settings**. Click the
  **Environment Variables...** button, select `PATH`, and add the directory
  containing your `bash` installation.
  - For MinGW/MSYS, this path will likely be `C:\MinGW\msys\1.0\bin`.
  - For the Git installation, this path will likely be `C:\Program
    Files\Git\usr\bin`, and the Git installer may have already added it to your
    `PATH`.

It should not be necessary to set Bash as your default shell. On Windows,
however, you may wish to run `bash` before executing the `./go` script or any
other Bash scripts, to avoid having to run it as `bash ./go` every time.

#### Recommended utilities

The framework as-is does not require any other external tools. However, in order
for the automatic command help and output formatting to work, you'll need the
following utilities installed:

- `fold` (coreutils)
- `tput` (ncurses) on Linux, OS X, UNIX; `mode.com` should be present on Windows

### Conventions

To use this framework, create a bash script in the root directory of your
project to act as the main `./go` script. This script need not be named `go`,
but it must contain the following as the first and last executable lines,
respectively:

```bash
. "${0%/*}/go-core.bash" "scripts"
@go "$@"
```

where `"${0%/*}"` produces the path to the project's root directory,
`go-core.bash` is the path to the file of the same name imported from this
repository, and `scripts` is the path to the directory holding the project's
command scripts relative to the project root.

#### Directory structure

The every `./go` script command will run from the project root directory where
the `./go` script resides. Your project structure may look something like this:

project/
  go - main go script
  scripts/ - project scripts
    bin/
    plugins/ - (optional) third-party command scripts
    go-script-bash/
      go-core.bash - top-level functions
      lib/ - utility functions
      libexec/ - builtin subcommands

This would imply that the first line of your `./go` script will look like:
```bash
. "${0%/*}/scripts/go-script-bash/go-core.bash" "scripts/bin"
```

The precedence for discovering commands is:

- aliases/builtins (provided by this framework)
- plugins (in `scripts/plugins` above)
- project scripts (in `scripts/bin` above)

#### Command scripts

Each command script for your project residing in the `scripts` directory must
adhere to the following conditions:

- No filename extensions.
- Must be executable, have `#!` line. The interpreter name will be parsed from
  this line.
- If `scripts/parent` is a command script, and you wish to implement subcommands
  as separate scripts, you must create a `scripts/parent.d` and place them
  there.

Bash scripts will be sourced. Other languages will use the `PATH` environment
variable to discover the interpreter for the script.

#### Command summaries and help text

The builtin `./go help` command will parse command script summaries and help
text from the header comment block of each script.

- The summary is parsed only from the first non-empty comment line other than
  the `#!`. The `./go` script name (or shell function name if you've used `./go
  env` to add it to your environment) are automatically prefixed. Conciseness
  encouraged.
- Table-like comments matching the pattern `^#   .*  ` will be automatically
  wrapped if the `COLUMNS` variable indicates a narrow screen. For this to work,
  each table entry mush not exceed one line. Conciseness encouraged.
- Subcommand script summaries will be automatically appended.
- The following placeholders are available:
  - `{{go}}`: the `./go` script name (or shell function name)
  - `{{cmd}}`: the name of the command (matches the basename of the script)
  - `{{root}}`: the project root directory (i.e. `_GO_ROOTDIR`)
- Add a "# Help filter" comment and parse a `--help-filter` flag to enable
  arbitrary text substitutions in the command description based on data from the
  script itself. This helps keep comments and data in-sync. For examples, see
  `libexec/aliases` and `libexec/builtins`. Some caveats:
  - You cannot use `{{go}}`, `{{cmd}}`, or `{{root}}` within the text expanded
    by `--help-filter`.
  - It is up to you to fold tabular content vis a vis $COLUMNS; with paragraph
    content, this is unnecessary.

#### Tab completion

#### Including common code

There are several methods available for sharing code between command scripts:

- Include common code and constants in the top-level `./go` script, after
  sourcing `go-core.bash` and before calling `@go`.
- Source a file in the same directory, hidden from command search by naming it
  with a leading dot. The path to source the file can be relative to
  `$_GO_ROOTDIR`.
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
`./go <command> [args..]`. In bash, however, you can also invoke the `@go`
function directly as `@go <command> [args...]`.

The `@go` and `@go.printf` functions are available to command scripts written in
bash, as bash command scripts are sourced rather than run using another language
interpreter.

The `_GO_ROOTDIR`, `_GO_SCRIPT`, and `COLUMNS` environment variables are
exported and available to scripts in all languages.

### Feedback and contributions

Feel free to [comment on or file a new GitHub
issue](https://github.com/mbland/go-script-bash/issues) or otherwise ping
[@mbland](https://github.com/mbland) with any questions or comments you may
have, especially if the current documentation hasn't addressed your needs.

If you'd care to contribute to this project, be it code fixes, documentation
updates, or new features, please read the [CONTRIBUTING](CONTRIBUTING.md) file.

## Open Source License

This software is made available as [Open Source
software](https://opensource.org/osd-annotated) under the [ISC
License](https://www.isc.org/downloads/software-support-policy/isc-license/).
For the text of the license, see the [LICENSE](LICENSE.md) file.

### Prior work

This is a Bash-based alternative to the
[18F/go_script](https://github.com/18F/go_script) Ruby implementation. This
`README` file and some of the implementation principles are borrowed directly
from that original repository.
