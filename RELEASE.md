# go-script-bash v1.1.2

This is a bugfix release.

## The `./go` script: a unified development environment interface

Source: https://github.com/mbland/go-script-bash

A `./go` script aims to abstract away many of the steps needed to develop (and sometimes deploy) a software project. It is a replacement for READMEs and other documents that may become out-of-date, and when maintained properly, should provide a cohesive and discoverable interface for common project tasks.

The `./go` script idea came from Pete Hodgson's blog posts [In Praise of the ./go Script: Part I](https://www.thoughtworks.com/insights/blog/praise-go-script-part-i) and [Part II](https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii).

**Note:** The `./go` script concept is completely unrelated to the [Go programming language](https://golang.org), though the Go language's `go` command encapsulates many common project functions in a similar fashion.

This software is made available as [Open Source software](https://opensource.org/osd-annotated) under the [ISC License](https://www.isc.org/downloads/software-support-policy/isc-license/). If you'd care to contribute to this project, be it code fixes, documentation updates, or new features, please read the `CONTRIBUTING.md` file.

## What's new in this release

### modules: Improved error handling for `. "$_GO_USE_MODULES"`

Previously, the `$_GO_USE_MODULES` script would report an `Unknown module:` error in every error case, even if the module existed but failed for another reason ([Issue #25](https://github.com/mbland/go-script-bash/issues/25)). The module's standard error would also get redirected to `/dev/null`, which made diagnosis even more difficult.

Now any modules that actually exist but return an error when imported will be identified as such, rather than being reported as unknown, and standard error isn't redirected at all ([PR #26](https://github.com/mbland/go-script-bash/pull/26)).

## Changes since v1.1.1

<pre>
22bace2 Mike Bland <mbland@acm.org>
        Merge pull request #26 from mbland/module-import

8833762 Mike Bland <mbland@acm.org>
        use: Improve module import error message

4bb94e2 Mike Bland <mbland@acm.org>
        use: Nest module file path tests

92bc468 Mike Bland <mbland@acm.org>
        use: Detect module path before sourcing

5ea7820 Mike Bland <mbland@acm.org>
        modules: Fix incorrect help text
</pre>
