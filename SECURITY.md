# Security Policy

## Supported versions

Only the latest release (tagged on `main`) is supported. Please update to the
latest version before reporting an issue.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Instead, report it privately via
[GitHub Security Advisories](https://github.com/mo6/gitgleam/security/advisories/new),
or by emailing g@mo6.nl.

Include what you'd include in any bug report: steps to reproduce, the
version/commit affected, and the potential impact. You should get a response
within a few days.

## Scope notes

Gitgleam is a local, unsandboxed macOS menu bar app that shells out to
`/usr/bin/git` and (optionally) a user-configured `viewmd.sh` script against a
repository path you point it at. It does not run as a service, accept network
input, or transmit data anywhere. Reports involving arbitrary code execution
via a specially crafted repository (e.g. through git output, commit
metadata, or Markdown/Mermaid content rendered in previews) are in scope.
