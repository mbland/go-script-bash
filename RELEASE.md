# go-script-bash v1.2.1

This release enhances the public stack trace feature and adds it to `@go.log FATAL` output.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

### Make `@go.print_stack_trace` take a numerical `skip_callers` argument

Previously `@go.print_stack_trace` would only skip the immediate caller if the first argument was not null. Now it enforces that the number be a positive integer, in order to skip over the specified number of callers while printing the stack trace. This was done to support better `@go.log FATAL` output, described below.

Normally an API change like this would warrant a major version bump, but since the impact should be minimal, it any potential for impact exists at all, it's included in this patch release.

### Include stack trace output on `@go.log FATAL` conditions

`@go.log FATAL` now prints a stack trace before exiting the process, since such information is generally useful under `FATAL` conditions. Every function in the `log` module that calls `@go.log FATAL` removes itself from the stack trace, so the top of the stack shows the location of the user code that triggered the condition, rather than the location of the `log` module function. 

## Changes since v1.2.0

<pre>
b2ad688 Mike Bland <mbland@acm.org>
        Merge pull request #28 from mbland/stack-trace

965782d Mike Bland <mbland@acm.org>
        log: Add stack trace to FATAL output

a0f4413 Mike Bland <mbland@acm.org>
        stack-trace: Move, add helpers to environment.bash

cd57da0 Mike Bland <mbland@acm.org>
        print-stack-trace: Add go-core stack test helper

8424338 Mike Bland <mbland@acm.org>
        print_stack_trace: Make skip_callers arg numerical
</pre>
