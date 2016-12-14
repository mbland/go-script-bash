# go-script-bash v1.2.0

This release adds a stack trace feature to the public API.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

### Print stack traces

The `@go.print_stack_trace` function is now part of the public API. Its original use case  was to provide more helpful error messages from `.  "$_GO_USE_MODULES"`, but it's generally useful. See the function comments in `go-core.bash` and `./go test --edit core/print-stack-trace` for more information.

## Changes since v1.1.2

<pre>
fb6f3ae Mike Bland <mbland@acm.org>
        Merge pull request #27 from mbland/stack-trace

30790c9 Mike Bland <mbland@acm.org>
        use: Show stack trace when an import fails

8563f4d Mike Bland <mbland@acm.org>
        core: Add @go.print_stack_trace to public API
</pre>
