# Disclaimer

Read this before putting anything you care about on a Local Drive server.

## This project is new

Local Drive is at version 0.0.1. It is early software, maintained in spare
time, and it may or may not keep receiving updates. There is no company behind
it, no support contract, and no promise that a given bug or vulnerability will
be fixed on any timeline, or at all.

That is not a disclaimer written by a lawyer to cover a product that is
actually fine. It is the real situation, and you should plan around it:

- Features may change or be removed between versions.
- A release may introduce a regression that nobody has hit yet.
- A reported security issue may sit unfixed if no maintainer has time.

**The community is the first and last line of defence.** If you find something
wrong, report it. If you can fix it, send the fix. A self hosted project is
only as sound as the people reading its code, and right now that is a small
number of people.

## What it was designed for

Local Drive was built for **personal use on a network you control**: a
household, a family, a few people who already trust each other and already
share a Wi-Fi network. That is the case it has been designed and tested
around.

It was **not** designed for:

- Commercial or business use, or anything where somebody else's data is your
  legal responsibility.
- Multi tenant hosting, where accounts belong to strangers.
- Regulated data. There is no compliance story here, for any regime.
- Being exposed directly to the public internet.

If your situation is on that list, use something with a security team and a
support contract. That is not false modesty, it is the honest recommendation.

## Do not expose this to the internet

The strongest advice in this document.

**Do not forward a port to this server. Do not put your public IP in the app.
Do not open your router to it.**

A file server reachable from the internet is scanned within hours of being
reachable, continuously, by people who do this at scale. Every unfixed bug in
this project becomes their opportunity, and this project is new enough that
nobody can tell you how many of those there are.

### Reach it from outside the safe way

If you need your files while away from home, use a VPN. The server stays
entirely private and unreachable from the internet, and you join your own
network from wherever you are.

**We strongly recommend [Tailscale](https://tailscale.com)**, or plain
WireGuard if you prefer to run it yourself. Tailscale needs no port forwarding,
no static IP and no firewall changes, and it takes about five minutes. Nothing
about your server becomes publicly reachable. This is the recommended way to
use Local Drive remotely, and it is the one the maintainers use.

If a VPN genuinely does not fit, a tunnel such as
[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
is the next best option: it gives you a real hostname and certificate without
opening a port. It is still a public front door, so put access control in front
of it.

Both are covered in [HTTP and HTTPS](docs/self-hosting/https.mdx).

## Back up your own data

Local Drive stores your files. It does not protect them from a failing disk, a
mistaken deletion, or a bug in this software.

One copy is not a backup. `localdrive backup` exists and works, and a backup
sitting on the same drive as the original is not a backup either. See
[Backups](docs/self-hosting/backups.mdx).

## No warranty

Local Drive is provided under the [MIT licence](LICENSE), which includes this
in capital letters and means it:

> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED.

You run this on your own machine, on your own network, at your own risk. The
maintainers are not liable for lost files, exposed data, or anything else that
follows from using it.

## Using it anyway

None of this is a reason not to. Plenty of good software starts here, and a
server on your own network, behind a VPN, holding your own family's photos, is
a reasonable thing to run at version 0.0.1.

Just do it knowingly, keep backups, and do not open the port.
