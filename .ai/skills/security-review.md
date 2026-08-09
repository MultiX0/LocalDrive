# Skill: reviewing a change for security

## Purpose

Catch the failures that matter in software holding files a person cannot
regenerate, before they ship.

## When to use

Any change touching authentication, permissions, sharing, uploads, downloads,
paths, the updater, or anything that executes a subprocess or fetches over the
network. Also as a standalone pass over an area.

## Required context

- `docs/architecture/security.mdx`, which is the permission and privilege model.
- [`SECURITY.md`](../../SECURITY.md) for reporting, and for what the project
  already assumes.
- The diff, and what it claims to do.

## Pre-flight

Establish the answer to one question before reading code: **what would an
attacker gain here?** Reading another account's files, taking over an account,
running code on the server, or destroying data. A review without a threat is a
style review.

## Workflow

Work through the areas the change actually touches. Do not pad a review with
areas it does not.

**Authorisation**

- Is the decision made in the domain package, not the handler?
- Is it made per object, on every request, using the caller's id rather than an
  id from the request body?
- Is there a test asserting a different account gets 403? Absence of that test
  is the finding.
- Does an administrator gain the ability to read another account's file
  contents? Admin is not a master key, and that is a product rule.

**Paths and filenames**

- Does any user supplied string reach a filesystem path without `pkg/pathsafe`?
- Consider `..`, absolute paths, symlinks, a trailing dot on Windows, a null
  byte, and a name that is legal on one platform and not another.

**Uploads and downloads**

- Is the body size capped?
- Can a resumable upload be resumed by someone who did not start it?
- Does a share link grant exactly the object it names, and nothing adjacent?

**Secrets and logs**

- Anything new that is committed and should not be. Check `.gitignore`.
- Any password, token, session id or key in a log line, an error message that
  reaches the client, or a crash report.
- Secrets are generated per install. There must be no default credential
  anywhere, including in examples and tests that get copied.

**Subprocesses and downloads**

- Arguments passed as a slice, never a shell string.
- Anything downloaded and then executed must be verified against a checksum or
  a signature. Transport security proves who served it, not what it is.

**Dependencies**

- A new dependency needs a reason. Does it pull in cgo, which would end the
  single binary property?
- Are GitHub Actions pinned to a tag rather than a moving branch? An action on
  `@master` executes whatever that branch contains at run time.

## Validation

```
cd server && go vet ./... && go test -race -count=1 ./...
```

Run the permission tests specifically, and add one if the change created a new
way to ask for an object.

CI additionally runs `govulncheck` and a container image scan. If a finding
appears there, it is a finding.

## Failure handling

- **You find a live vulnerability in shipped code:** stop. Do not open a public
  issue or a pull request that explains how to exploit it. Follow
  [`SECURITY.md`](../../SECURITY.md).
- **A fix would break a workflow:** report both. Never weaken the check to keep
  the workflow, and never remove the test that noticed.
- **You are unsure whether something is exploitable:** write it down as
  uncertain, with what you checked. An unproven concern that is stated is more
  useful than one that is dropped.

## Expected output

A short report, ordered by severity. For each finding: the file and line, what
an attacker gains, and the concrete fix. If nothing was found, say which areas
were actually examined, so the next reviewer knows what is still uncovered.

Never report a finding you have not confirmed against the source.

## Security considerations

This review is itself a place to leak things. Do not paste real tokens, real
paths from a user's machine, or the contents of a `.env` into a report, an
issue or a commit message.
