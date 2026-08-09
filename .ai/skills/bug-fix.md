# Skill: fixing a bug

## Purpose

Turn a reported symptom into a minimal, tested fix for the actual cause.

## When to use

Something behaves wrongly. Use it whether the report is precise ("returns 500
on rename") or vague ("the screen looks broken").

Do not use it for a feature request wearing a bug's clothing. If nothing is
broken and something is missing, that is a change of scope and needs asking.

## Required context

- The report, and how to reproduce it.
- Which surface it appeared on: server, client, or one platform of the client.
- Whether the install is Docker or the bare binary. A surprising number of
  behaviours differ, and assuming the wrong one wastes the whole investigation.

## Pre-flight

1. **Reproduce it first.** A fix for a bug you never saw is a guess. If it
   cannot be reproduced, say so and stop rather than changing code hopefully.
2. Find the owning code by searching for the symptom's text, the endpoint, or
   the widget. Do not start from the file you expect it to be in.
3. Read the tests around it. They frequently document the intended behaviour
   more precisely than the documentation does.

## Workflow

1. **Reproduce**, and capture the evidence: the failing output, the log line,
   the status code, the screenshot.
2. **Find the cause, not the symptom.** In this repository the symptom is
   often several layers from the cause. A broken screen has twice turned out to
   be two stacked non-UI bugs. Keep going until the explanation accounts for
   everything you observed, not just most of it.
3. **Write a failing test** that reproduces it. For the server that is usually
   a test in the owning package, or an integration test in `internal/app` when
   it spans packages. For the client it is usually a widget test.
4. **Fix it**, changing as little as possible.
5. **Watch the test go from red to green.** A test that never failed proves
   nothing.
6. Check whether the same mistake exists elsewhere. Causes here are often a
   pattern rather than one line.
7. Update documentation if the documented behaviour was what was wrong.

## Validation

```
cd server     && gofmt -l . && go vet ./... && go test -race -count=1 ./...
cd localdrive && flutter analyze && flutter test
cd landing    && npm run build
```

Run the checks for every component you touched, and the landing build for any
documentation change.

Then reproduce the original report one more time, the way it was originally
reported, and confirm it is gone.

## Failure handling

- **Cannot reproduce:** say so, describe what you tried, and ask for the
  version, the platform and the install type. Do not fix speculatively.
- **The fix breaks another test:** the other test is a specification until
  proven otherwise. Understand what it protects before touching it. Never
  delete or skip it to go green.
- **The cause is in a public contract:** stop and read
  [server-endpoint](server-endpoint.md) or the "Changing something public"
  section of `AGENTS.md`. A bug fix that silently changes an API response is
  two changes.

## Expected output

- The smallest diff that fixes the cause.
- A regression test that fails without the fix.
- A summary saying: what the symptom was, what the cause was, what changed,
  what you ran, and what you could not verify.

Do not claim it is fixed on the strength of reading the code. Show the evidence
and name anything still untested.

## Security considerations

If the bug is a permission check that did not fire, a path that escaped its
directory, a token that was accepted when it should not have been, or anything
that let one account touch another's data, then it is a vulnerability rather
than a bug. Stop and follow [`SECURITY.md`](../../SECURITY.md) instead of
opening a public pull request that describes how to exploit it.
