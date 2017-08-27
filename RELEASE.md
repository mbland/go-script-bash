# go-script-bash v1.6.0

This is a minor update to add the capability to `go-template` to download a release tarball from GitHub rather than using `git clone` to add the go-script-bash framework to a project working directory.

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

All of the issues and pull requests for this release are visible in the [v1.6.0 milestone][].

[v1.6.0 milestone]: https://github.com/mbland/go-script-bash/milestone/4?closed=1

### Download a go-script-bash release tarball from GitHub in `go-template`

Thanks to [Juan Saavedra][elpaquete], `go-template` now has the capability to download and unpack a release tarbal from GitHub in order to add the go-script-bash framework to a project's working directory, rather than relying on `git clone`. Now `git clone` will be used as a backup in case the system doesn't have the tools to download and unpack the tarball, or the operation fails for some reason.

[elpaquete]: https://github.com/elpaquete

### Bug fixes

None in this release.

## Changes since v1.5.0

You can see the details of every change by issuing one or more of the following commands after cloning: https://github.com/mbland/go-script-bash

<pre>
$ ./go changes v1.5.0 v1.6.0
$ gitk v1.5.0..HEAD
</pre>
