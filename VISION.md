# Local Drive Vision

This is the long-term north star for the project. It exists so that maintainers,
contributors and AI coding agents can answer one question without asking anyone:
**does this change belong in Local Drive?**

It is not documentation of how the software works. That lives in
[`docs/`](docs/). This file is about direction and judgement.

Two rules govern it. Everything described as current has been built and can be
verified in this repository today. Everything else is labelled by how far away
it is. If you find a claim here that the code does not support, that is a bug in
this file and it should be fixed like any other.

---

## Why Local Drive exists

Cloud storage solved a real problem. Files became available everywhere, survived
a dropped laptop, and could be shared with a link instead of an attachment.
Nobody wants to give that up.

The cost was ownership. Files that matter, tax records, photographs of people
who are no longer here, years of work, now sit on infrastructure the owner does
not control, under terms they did not negotiate, reachable only while an account
is in good standing. The data is not gone, it is just held by someone else, and
the difference only becomes visible on the day access stops.

The usual answer is to self-host, and for most people that answer does not
work. It assumes someone who is comfortable with reverse proxies, certificates,
container orchestration, database backups and port forwarding. That is a small
fraction of the people who have something worth keeping.

Local Drive exists to close that gap. Not by making self-hosting more powerful,
but by making it ordinary. The target user is someone who can download a file
and double-click it, and who should not have to become a systems administrator
to keep their own photographs.

## The core idea

Five statements, in order of importance. Later ones give way to earlier ones.

1. **Your files live on hardware you control.** Not synced to it. Not cached on
   it. They are there, and no third party is between you and them.
2. **The server is the source of truth.** It owns the data, the accounts, the
   permissions and the decisions. Everything else is a view of it.
3. **Clients are replaceable windows.** Delete every client and lose nothing.
   Move to a different client and everything is still there. A client that
   becomes load-bearing is a bug.
4. **No third-party account is required, ever.** Not to install it, not to run
   it, not to use it. A domain is optional. An internet connection is optional.
5. **A person should be able to understand the whole thing.** Not every line,
   but the shape: where files go, who can read them, what happens on restore.

## What Local Drive is not

This section carries as much weight as the one above it. A project is defined
by what it declines.

- **Not a sync client.** Files are stored on a server and handed to clients on
  request. Offline availability is a per-device choice, not a mirror of a disk.
- **Not a peer-to-peer file beam.** Sharing goes through the server, so the
  other person still has access next week from a different device.
- **Not a directory you write into by hand.** Storage is content-addressed. The
  backing directory is the server's, in the same way a bucket belongs to the
  cloud provider that manages it.
- **Not a SaaS product wearing self-hosting as a costume.** There is no hosted
  tier that gets the real features. There is no licence server, no telemetry
  endpoint, no phone-home.
- **Not an enterprise stack.** If running it starts to require an orchestrator,
  a message broker and a separate cache, the design took a wrong turn. Nobody
  should need a cluster to hold their own files.
- **Not a lock-in ecosystem.** The API is plain REST and WebSocket. Anyone can
  write a different client, and that is a supported outcome rather than a
  tolerated one.
- **Not an unmaintained pile of generated code.** AI agents contribute here.
  They do not own the architecture, and code nobody understands does not merge.
- **Not a project that trades user ownership for convenience.** When the two
  conflict, ownership wins and the inconvenience gets documented.

## The server is the product

The Go binary in [`server/`](server/) is Local Drive. The Flutter application
is the way most people will see it, and it is still an interface.

The server owns, exclusively:

- the files and their content-addressed storage
- accounts, sessions and second factors
- permissions, and their enforcement on every single request
- versions, trash and restore
- shares, links and invitations
- storage locations and drive rules
- the audit record

A client may cache any of this for speed. A client may never be the only place
something is true. The test for any proposed feature: if every client were
uninstalled right now, is anything lost? If yes, it belongs on the server.

This is why the server ships as one binary with no runtime dependency, built
with `CGO_ENABLED=0` against a pure-Go SQLite driver. A dependency that breaks
the single-file property trades away the main thing the project offers, and
needs a much stronger reason than convenience.

## Self-hosting philosophy

The hardware people already own is the target. A laptop that was replaced, a
small home server, a low-cost VPS, a single-board computer. Not a rack.

The commitments that follow from that:

- Setup is a download and a run. Not a compose file someone has to read first.
- Defaults are correct for a home network, not for a data centre.
- Plain HTTP on a LAN address is the default and is not an oversight. No
  certificate authority signs an address like `192.168.1.10`, and a self-signed
  certificate makes clients refuse to connect. HTTPS turns on when a domain
  exists.
- One process. Optional helpers stay optional, and their absence degrades a
  feature rather than stopping the server.
- Every destructive operation has a way back: backup, rollback, restore.

Documented hardware expectations live in
[`docs/self-hosting/requirements.mdx`](docs/self-hosting/requirements.mdx) and
are the authority. This file does not restate them, because two copies of the
same number means one of them is out of date.

## Product principles

In tension, higher wins.

1. **Ownership.** The user's data is the user's.
2. **Security is explicit.** Permission is granted, never inherited by accident.
3. **Recoverability.** Anything destructive is reversible or backed up first.
4. **Portability.** Data can leave. Formats stay inspectable.
5. **Simplicity.** The smallest design that actually solves the problem.
6. **Honesty.** The software and its documentation describe the same system.
7. **Cross-platform parity where it is real.** Where a platform genuinely cannot
   do something, say so rather than shipping a stub.
8. **Accessibility and internationalisation are features.** Right-to-left
   layout and screen readers are requirements, not a later pass.
9. **Backwards compatibility for anything public.** The API, the CLI, the
   on-disk layout and the configuration are contracts.
10. **Understandable to contributors, human or otherwise.**

### Admin is not a master key

Serious enough to state separately. An administrator manages the server:
accounts, storage, settings, updates. An administrator cannot silently read
another account's files. Adding a bypass for convenience or for support is a
change to the product's meaning, not a feature.

## Open source philosophy

MIT licensed, with no contributor licence agreement.

What that is meant to produce: a system someone can inspect end to end, build
from source, run without asking permission, fork if the maintainers go in a
direction they dislike, and extend through the API without negotiating.

A good contribution is small, has a reason written in the description, matches
the code around it, carries tests when it changes behaviour, and updates the
documentation it invalidates.

## AI-agent philosophy

AI agents write code in this repository. That is treated as normal, and it is
governed rather than either banned or trusted blindly.

The position:

- **Agents are contributors. Humans are maintainers.** An agent proposes
  changes. A person owns the architecture and accepts them.
- **Vendor neutrality is a hard requirement.** Agent instructions live in plain
  Markdown files that any tool can read. The repository must never require a
  specific AI product to build, test, release or contribute. Remove every AI
  file and the project is unchanged.
- **Inspect before editing.** The most expensive failure mode is an agent that
  invents an architecture next to the one that already exists.
- **Verification is not optional.** A claim that a test passed, when it was
  never run, is worse than no claim at all, because it costs a reviewer their
  trust in everything else in the change.
- **Uncertainty gets reported, not resolved by guessing.** "I could not
  determine X" is a useful contribution. A confident wrong answer is not.

The working rules are in [`AGENTS.md`](AGENTS.md), and the per-area rules are in
the `AGENTS.md` file nearest the code being changed.

## Testing philosophy

Correctness is part of the product, because the thing being protected is data
that cannot be regenerated.

Tests are chosen by what they protect, not by coverage percentage. A number
that goes up while the upload path stays untested is worse than no number.

The workflows that must not break, roughly in order: a user does not lose a
file, a user cannot read another user's file, an upload that was interrupted
can finish, a restore actually restores, and an update that fails rolls back.

Layers and what belongs in each are described in
[`docs/contributing/testing.mdx`](docs/contributing/testing.mdx).

## Security philosophy

The threat model starts from the fact that this software holds everything
someone chose to keep.

- Authorisation is checked on the server, on every request, for every object.
- Secrets are generated per install and never committed. There is no default
  credential anywhere in the project.
- Path handling is defensive at every boundary where a name reaches a
  filesystem.
- Insecure defaults are not offered as a convenience toggle.
- Reports go to a private channel first, per [`SECURITY.md`](SECURITY.md).
- Where a security property is not yet met, it is written down rather than
  implied. An unstated gap is worse than a stated one.

Convenience never wins this argument. If a change makes something easier by
making it less safe, it is a different change and needs to be argued on those
terms.

## Documentation philosophy

Documentation is part of the feature, not the cleanup after it.

- [`docs/`](docs/) is the single source. The website renders it directly, so
  there is nothing to copy and nowhere for the two to disagree.
- A command that appears in documentation exists and was run.
- Output shown in documentation was captured, not written from memory.
- A feature nobody can find is unfinished.

---

## Current state

Everything in this section exists in the repository now and can be checked.

**Server.** One Go binary. REST and WebSocket API, SQLite via a pure-Go driver,
content-addressed storage, resumable uploads, folders, versions, trash, search,
sharing, multi-user permissions, audit records, LAN discovery, thumbnails and
media metadata, backups, self-update with rollback, and a CLI covering setup,
service installation, status, logs, backup and update.

**Authentication.** Password accounts, device approval for new devices, TOTP
second factor, required for administrators and optional for everyone else.

**Deployment.** Docker Compose with Caddy in front, or the bare binary on its
own. The bare binary obtains and renews its own certificate when a domain is
set, and answers plain HTTP on the same port for addresses a certificate cannot
cover.

**Clients.** One Flutter codebase. Files, gallery, previews, transfers, sharing,
offline availability, nearby sharing, storage and drive management, settings and
administration. English and Arabic, including right-to-left layout.

**Quality.** Go tests across the API, permissions, media, path safety and the
CLI, run with the race detector. Flutter widget and unit tests. Continuous
integration runs formatting, vet, tests, a vulnerability scan, an image build
and scan, and cross-compilation for six targets.

### Known gaps in the current state

Stated plainly, because a vision document that hides them is marketing.

- **Not every supported platform is a published build.** The server publishes
  Linux amd64, Linux arm64 and Windows amd64. macOS is supported and built from
  source on purpose, because an unsigned published binary is quarantined by
  macOS and fails its first run in a way that looks like broken software. The
  client publishes Android, Windows and Linux; iOS, macOS and web build from the
  same source and are not released. Both are recorded in
  [`docs/contributing/security-review.mdx`](docs/contributing/security-review.mdx).
- **The bare binary serves the API only.** The browser interface is served by
  Caddy under Docker, from a directory that is empty in the repository because
  the built web client is an artifact. Running the binary directly gives the API
  and the clients, not a browser UI.
- **The optional ffmpeg download is not checksum verified.** It is fetched over
  HTTPS from a third-party host and executed, because no upstream publishes a
  versioned build stable enough to pin against. The trust is stated in the log
  and the download can be turned off. Reasoning in
  [`docs/contributing/security-review.mdx`](docs/contributing/security-review.mdx).

## Near-term objectives

The next things that matter, without dates.

- End-to-end coverage of the workflows where data loss is possible, starting
  with backup, destroy and restore.
- A browser interface story that does not depend on which deployment was chosen.
- A signing identity for macOS, which is what stands between the current source
  build and a published one.
- Keeping the website's install instructions from drifting out of step with
  `docs/`, which they have done once already.

## Long-term direction

Where the project is going, with no commitment that any specific item ships.

- Stronger synchronisation, including conflict handling that a person can
  understand and reverse.
- Backup and restore that a non-expert can rely on, including verifying that a
  backup would actually restore.
- Richer sharing: expiry, permissions on links, and shares that survive the
  sharer changing device.
- Administration that scales to a household or a small team without becoming an
  identity management product.
- Storage management across several disks and external drives as one library.
- Observability that helps a self-hoster diagnose their own server.
- Migration in and out, treated as a first-class feature because portability is
  a principle rather than a checkbox.

## Aspirational

Ideas that fit the philosophy and have no design yet. Listed so they are not
mistaken for plans.

- Collaborative editing of documents held in the drive.
- An extension surface for third-party features that does not compromise the
  security model.
- Federation between independently owned servers.
- Automation and rules over files.

---

## Decision framework

For any proposed change, in this order. A no on an early question is not
outweighed by a yes on a later one.

1. **Does it keep the user in control of their data?** If it moves authority
   off the user's hardware, it does not belong here.
2. **Does it introduce a dependency on a vendor?** Including AI vendors. If the
   project stops working when a company changes its terms, that is lock-in.
3. **Does it make self-hosting harder?** A feature that adds a required service
   costs every operator forever.
4. **Does it weaken security or make a permission implicit?** If yes, it needs
   to be argued as a security change, not as a feature.
5. **Is anything now recoverable only in one place?** Data loss beats every
   other consideration.
6. **Does it change a public contract?** The API, the CLI, the on-disk layout
   and the configuration are contracts. Changing one is a versioned event with
   documentation and a migration path.
7. **Can it be done more simply?** Usually yes. The simpler version is usually
   right.
8. **Is the architecture easier or harder to explain afterwards?** Harder is a
   real cost and should be paid deliberately.
9. **Does it solve a problem a real user has?** As opposed to one the
   implementer finds interesting.

If a change fails on 1, 2 or 4, no amount of implementation quality rescues it.

## What success looks like

- People who are not systems administrators are successfully running their own
  server, and keeping it running through updates and reboots.
- When something breaks, the person who owns the machine can find out why.
- Backups restore. Migrations complete. Rollbacks work.
- A contributor can find the right file on their first day.
- An AI agent can make a correct, scoped, reviewable change without a maintainer
  reconstructing the project's philosophy from scratch.
- Someone can fork it and keep going without asking.

Explicitly not the measure: stars, download counts, dependency totals,
architectural fashion, or how impressive the repository looks to someone who
never runs it.

---

## The final principle

Software that holds your files should be software you could walk away from
without losing them.

Everything here follows from that. If a decision would make leaving harder, it
is the wrong decision, however convenient it looks.
