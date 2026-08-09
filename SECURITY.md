# Security policy

Local Drive holds people's files. Security reports are welcome and taken
seriously, including ones that turn out to be wrong.

## Notice, read this first

**This project is at version 0.0.1 and is maintained in spare time.** There is
no security team and no guaranteed response. A reported vulnerability may be
fixed quickly, slowly, or not at all, depending on who has time. The community
reading and fixing this code is the first and last line of defence.

**Local Drive is designed for personal use on a network you control**, inside a
household or family. It is not built for commercial use, for multi tenant
hosting, or for data that is somebody else's responsibility.

**Do not expose this server to the public internet.** Do not forward a port to
it. If you need it while away from home, use a VPN such as
[Tailscale](https://tailscale.com), which the maintainers strongly recommend
and use, or WireGuard. If a VPN does not fit, use a tunnel such as Cloudflare
Tunnel rather than opening a port.

The full version of this is in [DISCLAIMER.md](DISCLAIMER.md), and it is worth
reading before you trust this with anything.

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private reporting, which goes only to the maintainers:

[Report a vulnerability](https://github.com/MultiX0/LocalDrive/security/advisories/new)

If that is unavailable, open a normal issue saying only that you have a
security report and asking for a contact address. Do not include details.

### What helps

- What an attacker can do, and what they need to start with. "Any signed in
  user can read another user's files" is actionable. "The API looks insecure"
  is not.
- Steps to reproduce, ideally a request or a short script.
- Which version, and whether it runs under Docker or as the bare binary.

### What to expect

- An acknowledgement within a few days.
- An assessment, including a plain statement if it is not a vulnerability and
  why.
- A fix in a release, with credit in the release notes unless you prefer not
  to be named.

There is no bug bounty. This is a project maintained in someone's spare time,
and pretending otherwise would waste yours.

## Supported versions

The newest release. This project is pre-1.0 and there are no maintained
release branches yet, so fixes land in the next version rather than being
backported.

## Scope

In scope, and interesting:

- Reading, writing or deleting files across account boundaries
- Bypassing device approval, or getting a token without valid credentials
- Path traversal out of a library directory
- Share links that grant more than they should, or outlive their expiry
- Anything that lets an ordinary account act as an admin

Out of scope, because they are documented behaviour rather than defects:

- **Plain HTTP on a LAN address.** This is the default and the reasoning is in
  [HTTP and HTTPS](docs/self-hosting/https.mdx). Reports that traffic is
  readable on the local network will be closed as intended.
- **An admin can reach the machine.** An admin runs the server. There is no
  boundary being crossed.
- Anything requiring physical access to an unlocked machine, or the ability to
  read `data/db/secrets.env`. Whoever can read that file already owns the
  install.
- Missing hardening headers with no demonstrated impact.
- Findings from an automated scanner, pasted without a working reproduction.

## What the project already assumes

Stated here so reports can be aimed at real gaps rather than design decisions:

- New devices need approval by default, so a leaked password alone does not
  grant access.
- Admin is not a master key. An admin can manage the server and accounts, and
  cannot silently read another account's files.
- Secrets are generated per install on first run. No default credentials ship
  anywhere.
