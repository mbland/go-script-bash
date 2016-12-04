# go-script-bash v1.1.1

This is a bugfix release.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

### log: Replace `echo -e` with `printf`

On at least one macOS 10.12.1 installation, `echo -e` under Bash 3.2.57(1)-release in Terminal.app wasn't converting `\e` sequences to actual ANSI escape sequences. Using `printf` instead resolves the issue.

## Changes since v1.1.0

<pre>
187715e Mike Bland <mbland@acm.org>
        Merge pull request #24 from mbland/printf-esc-seqs

4bc05c8 Mike Bland <mbland@acm.org>
        log: Replace `echo -e` with `printf`
</pre>
