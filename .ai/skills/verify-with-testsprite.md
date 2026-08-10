# Verify with TestSprite

Use when a change is finished and the behaviour it changed is the kind a person
would notice: a screen, a workflow, an endpoint, a permission.

The mechanics, meaning every command, every flag, the plan schema and the
failure bundle format, are in TestSprite's own skill. The CLI installs it and
keeps it in step with its own version:

```bash
testsprite agent install --target claude
```

`testsprite agent list` shows the other supported targets. Those files are
generated and git ignored, so install the one for whichever agent you are.

This file holds only what that skill cannot know: what matters in *this*
project, and what a failure here usually means.

## Getting the tool at all

Run this first. Everything below assumes it answered:

```bash
testsprite --version
testsprite auth status
```

If either fails, work through this in order. Do not skip to "I cannot verify
this" until you have actually offered the steps.

### 1. Is there a Node at all

```bash
node --version    # needs 20.19+, 22.13+ or 24+
npm --version
```

Odd numbered releases (21.x, 23.x) are not supported. If Node is missing or too
old, say which and offer the line for the machine you are on:

```bash
# macOS, or Linux with Homebrew
brew install node

# Debian or Ubuntu, via nodesource
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt-get install -y nodejs

# Windows
winget install OpenJS.NodeJS.LTS

# any platform, if the version has to be managed per project
# https://github.com/nvm-sh/nvm
nvm install 24 && nvm use 24
```

Anything else: [nodejs.org/en/download](https://nodejs.org/en/download).

Installing a runtime changes the machine, so ask before running one of these
rather than doing it silently.

### 2. Install the CLI

```bash
npm install -g @testsprite/testsprite-cli
testsprite --version
```

If a global install is refused, or you would rather not touch the machine,
every command in this file works with `npx @testsprite/testsprite-cli` in place
of `testsprite`.

### 3. Get an API key

There is no way around this one: the key belongs to a person, and it comes from
TestSprite's dashboard. Walk the user through it rather than guessing:

1. Open [testsprite.com](https://www.testsprite.com/) and sign in, or create an
   account.
2. Go to the dashboard, then **Settings**, then **API Keys**.
3. Create a key and copy it.

Then, in order of preference:

- **Best: the user runs it.** Ask them to run `testsprite setup` in their own
  terminal and paste the key at the prompt. It is written to
  `~/.testsprite/credentials` with mode `0600` and the key never passes through
  this conversation at all.
- **If they hand you the key instead:** put it in the environment for the
  session and nowhere else.

  ```bash
  export TESTSPRITE_API_KEY=…
  ```

  Never write it to a file in this repository, never echo it back, never put it
  in a commit, a log, a comment or a pull request description. If it has already
  been pasted somewhere it should not be, say so and tell them to rotate it.

Confirm before going further:

```bash
testsprite auth status
testsprite doctor
```

`doctor` names whichever piece is still missing: version, profile, credentials,
connectivity, or the agent skill.

### 4. Install TestSprite's own agent skill

Worth doing once, because it carries the full command surface and stays matched
to the CLI version:

```bash
testsprite agent install --target claude
```

`testsprite agent list` shows the other targets. These files are git ignored, so
each contributor installs the one for their own tool.

## Before anything else

TestSprite drives a browser from the cloud. **It cannot reach `localhost`**, and
Local Drive is a self hosted project, so the default state of a change is
"running only on this machine".

Decide this first, because it determines whether the rest applies:

- Is the change deployed somewhere public? Use the CLI.
- Is it only running locally? Use the TestSprite MCP if this session has it. It
  is the one interface that can reach a local app, which is why it is worth
  reaching for here rather than treated as an alternative to the CLI.
- Neither available? Then say so plainly: "shipped but not verified at the
  end-to-end layer, because it is not deployed anywhere reachable and the MCP is
  not available here", and stop. Do not point the suite at a stale deployment to
  produce a verdict; a pass against last week's build is worse than no verdict,
  because it reads like one.

**Never report a TestSprite result you did not get.** No credentials, no
project, no reachable target: say which, and call the change unverified at this
layer. An invented verdict is worse than an honest gap, because the next person
will trust it.

## Never commit what the tools generate

The MCP writes `testsprite_tests/`, including a `tmp/config.json` that can carry
the API key and a `code_summary.json` that maps the codebase. The CLI writes
`.testsprite/`, including failure bundles full of screenshots. All of it is
ignored, and it stays that way.

The only TestSprite files this repository tracks are the hand written ones in
`e2e/testsprite/`. If you add a test, it goes there, as a plan or a Python file,
reviewed like any other change.

## When it is worth running

The layers below are cheaper and closer to the failure. Run them first, always:

```
cd server     && go test -race -count=1 ./...
cd localdrive && flutter analyze && flutter test
```

Reach for this layer when the change touched something those cannot see:

- Signing in, sessions, device approval, the second factor.
- What one account may see of another's. This is the highest value thing this
  project can assert.
- Upload, download, resume, versions, trash and restore. Anywhere a person
  could lose a file.
- Sharing, and what a share link exposes to somebody not signed in.
- A screen's actual behaviour: navigation, a listing that has to refresh, an
  interface state that only appears against a real server.
- The API contract a client reads. A renamed field is a broken client.

Skip it for documentation, comments, formatting, a lockfile bump, or an internal
refactor that cannot change what a client receives. Running it there costs
credits and proves nothing.

## What is already covered

Look before writing a new test. `e2e/testsprite/README.md` lists what each file
covers; extending an existing plan usually beats adding a near duplicate.

```bash
testsprite test list --project "$TESTSPRITE_PROJECT_ID" --output json
```

## Writing a good plan for this project

- **Assert the thing that would be wrong.** "Verify the page loads" passes while
  the feature is broken. "Verify the uploaded file's name appears in the
  listing" does not.
- **Name the behaviour, not the screen.** "Signing out returns to the sign-in
  form", not "settings page".
- **One verb per step.** Split anything joined by "and".
- **No selectors.** Describe intent. The agent finds the control, and a plan
  pinned to a class name breaks on the next refactor.
- **Priority honestly.** `p0` is losing a file or letting the wrong person read
  one. Most things are not `p0`.

## Reading a failure

Get the bundle before forming a theory:

```bash
testsprite test result <test-id> --include-analysis
testsprite test failure get <test-id> --out ./.testsprite/failure --failed-only
```

Then decide which of three things is true. This is the whole job:

1. **The application is wrong.** Fix the application, and add the cheaper test
   too: if a unit or integration test could have caught it, that is where the
   regression test belongs rather than here.
2. **The product changed on purpose.** Update the plan, in the same commit as
   the change that caused it, so the diff shows both.
3. **The environment is wrong.** A deployment mid-rollout, a fixture account
   that was removed, a network fault. Fix the environment and run again.

**Never edit a test to make it pass.** The intended behaviour is the source of
truth. A suite edited until it is green still costs time to run and no longer
tells anybody anything.

## Reporting

Say what ran and what it returned. Either a terminal verdict, one of `passed`,
`failed`, `blocked` or `inconclusive`, or an explicit statement that none was
obtained and why. "I implemented it and the unit tests pass" is not a verdict at this layer,
and neither is a test that was drafted but never run.
