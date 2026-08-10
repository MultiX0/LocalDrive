# TestSprite suite

The end-to-end layer. These tests drive a running Local Drive the way a person
would, against a server that is actually deployed somewhere.

The full guide is [TestSprite](../../docs/contributing/testsprite.mdx). This
file is the map of what is in this directory.

```
e2e/testsprite/
  frontend/   one .plan.json per user workflow, in plain language
  backend/    one .py per API contract, asserted over HTTP
```

## The one thing to know first

**TestSprite runs from the cloud, so it can only reach a public address.** The
CLI rejects `localhost` and private ranges outright. That is not a setting to
turn off; it follows from where the browser doing the driving lives.

A self hosted project feels this more than most, because the obvious place to
develop is a laptop nobody else can route to. So:

- The layers below this one, `go test` and `flutter test`, stay the fast local
  loop and are where most changes are proven.
- This layer runs against a deployment: a staging server, a preview, or your
  own instance on a domain.
- If a change only exists on your machine, this layer cannot verify it yet, and
  saying so is the correct outcome rather than pointing it at a stale
  deployment to manufacture a verdict.

The backend files are also plain Python, so they can be run directly against a
local server while writing them. See below.

## Frontend plans

A plan is the behaviour, in sentences. There are no selectors in it, because
the agent driving the browser reads intent and finds the control itself, and a
plan pinned to a class name breaks on the next refactor.

Each file is one workflow, named for the behaviour it asserts rather than the
screen it visits. `projectId` is the literal `PROJECT_ID`; it is replaced at
create time, so nobody's project id is baked into the repository.

Validate them without an account, network or key:

```bash
npx @testsprite/testsprite-cli test lint --plan-from-dir ./frontend
```

Exit `0` means every file is schema correct. Exit `5` lists what is wrong.
Worth running before opening a pull request that touches this directory.

## Backend tests

Plain Python over HTTP, asserting the API contract rather than the interface.
The runner executes each file top to bottom and does **not** collect
`test_*` functions the way pytest does, so every file ends by calling its own
tests. A function that is only defined would pass without asserting anything.

The sandbox has the standard library, `requests`, `pytest`, `numpy` and
`scipy`. It cannot import Local Drive's own source, which is the point: these
assert what a client receives over the wire.

`TARGET_URL` is injected by TestSprite. The files fall back to `LOCALDRIVE_URL`
so the same assertions can be run against a local server while writing them:

```bash
LOCALDRIVE_URL=http://127.0.0.1:7443 python e2e/testsprite/backend/test_status_contract.py
```

No output and exit `0` means it passed.

## What is covered

Ordered by what the project says must not break, in
[Testing](../../docs/contributing/testing.mdx).

| Area | Where |
| --- | --- |
| A wrong password is refused, and no token is issued | `backend/test_login_rejects_bad_credentials.py`, `frontend/02-…` |
| Nothing owned by an account is readable without a session | `backend/test_unauthenticated_access_is_refused.py` |
| The status contract every client reads | `backend/test_status_contract.py` |
| A share link is the only unauthenticated surface, and an unknown token is refused | `backend/test_share_link_rejects_unknown_token.py` |
| A client hosted anywhere can reach the server, and media stays readable | `backend/test_any_origin_may_reach_the_api.py` |
| Signing in, and signing out again | `frontend/01-…`, `frontend/09-…` |
| A file survives being uploaded and comes back | `frontend/03-…`, `frontend/04-…` |
| Folders, trash, rename, search, sharing | `frontend/05-…` through `frontend/10-…` |

## What is not covered yet

Worth being explicit, because a gap nobody wrote down is a gap nobody fills.

- **One account reading another account's file.** The single most valuable test
  this project could have. It needs two seeded accounts on the target
  deployment; the credential model here injects one. Add it when a second
  fixture account exists.
- **Resuming an interrupted upload.** Needs a run that can cut a connection
  part way.
- **Backup, destroy, restore.** The promise the whole project rests on, and the
  least likely to be caught anywhere else. It is not a browser workflow, so it
  probably belongs in a scenario beside this directory rather than inside it.

## Test data

Use a dedicated account on a deployment that holds nothing anyone would miss.
Never point this suite at a server holding real files: the frontend plans
create folders, rename files and move things to the trash, and a failure bundle
captures screenshots of whatever was on screen.
