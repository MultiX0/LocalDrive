<div align="center">

<img src="docs/assets/mark.svg" width="96" alt="">

# Local Drive

**Your own file server, on your own hardware.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Go](https://img.shields.io/badge/go-1.25-00ADD8.svg)](server/go.mod)
[![Flutter](https://img.shields.io/badge/flutter-3.44-02569B.svg)](localdrive/pubspec.yaml)

[Documentation](docs/introduction.mdx) ·
[Server](server/) ·
[App](localdrive/) ·
[Website](landing/)

</div>

---

Local Drive is a private alternative to Google Drive that runs on a computer you
own. Your files stay on your machine. There is no account to make with anyone,
no subscription, and no company in the middle.

**The server is the product. The apps are just windows onto it.**

Everything lives in the server: your files, the accounts, the permissions, the
versions, the sharing. Every rule is decided there and enforced there, on every
request. That is the piece you install, the piece you back up, and the piece
that is actually yours.

The phone, desktop and browser apps hold nothing of their own. They ask the
server what exists and show it. Uninstall every one of them and you have lost
nothing, because none of them were ever where your files were. Point a fresh
one at the same address and everything is back. You can also skip them
entirely and use a browser.

---

## Run it in three steps

### 1. Download the server

One file, no runtime and nothing to install. Grab `server` for Linux or
`server.exe` for Windows from
[the latest release](https://github.com/MultiX0/LocalDrive/releases/latest),
and rename it to `localdrive` if you like.

### 2. Start it

```
./localdrive
```

That is the whole command. There is nothing to configure first. It asks a few
questions, generates every secret it needs, and starts. You never have to
invent a password for anything internal.

To keep it running after a reboot, see
[Keeping it running](docs/self-hosting/running-always.mdx): systemd on Linux,
Task Scheduler on Windows.

### 3. Open it

Go to `http://localhost:7443` in your browser.

The first screen asks you to make an admin account. That is you. Done.

Plain HTTP is the default, because no certificate authority will issue a
certificate for an address on your own network. If you have a domain pointing
at the machine, set `LD_DOMAIN` in `.env` and Caddy gets a real certificate on
its own. See [HTTP and HTTPS](docs/self-hosting/https.mdx).

---

## Use it from your phone

1. On the computer running the server, find its address on your network. On
   Windows run `ipconfig`, on macOS or Linux run `ifconfig`. Look for something
   like `192.168.1.10`.
2. Install the Local Drive app on your phone.
3. The app scans your network and should find the server on its own. Tap it.
   If it does not appear, type the address, for example `192.168.1.10`.
4. Sign in with the account you just made.

---

## Everyday commands

```
localdrive          set everything up, asking a few questions
localdrive serve    run it in this terminal
localdrive status   where it is, and whether it is running
localdrive logs     follow the log
localdrive backup   copy your files and database somewhere safe
localdrive update   check for a new release and install it
```

Every command is in the [CLI reference](docs/self-hosting/cli.mdx). It runs on
Windows, macOS, and Linux.

---

## Do you need Docker?

**Probably not, and the binary is the better default.** One process instead of
three, a start measured in milliseconds, and a memory footprint in the tens of
megabytes. On an old laptop or a Raspberry Pi with 1 GB of RAM that matters:
the Docker daemon by itself costs more than this entire server does.

A `docker-compose.yml` ships in `server/` and is worth using when you want one
of three specific things, all of which are separate services the bare binary
cannot provide:

- Automatic HTTPS through Caddy, for a real domain
- Drive management from inside the app, which is Linux only
- Network discovery, so phones find the server without typing an address

```
cd server
docker compose up -d
```

See [Running without Docker](docs/getting-started/without-docker.mdx) for
exactly what each option costs you.

---

## Add other people

Local Drive does not let strangers sign up. To give someone an account:

1. Open **Settings**, then **Users**.
2. Tap **Invite someone** and give the invite a name, like "Mom".
3. Send them the code, the link, or the QR code however you normally talk.
4. They enter it on their own device and pick their own username and password.
   You never see or handle either.

Each person gets their own private space. Being an admin means you manage
accounts, storage, and settings. It does **not** mean you can read anyone
else's files.

---

## What it does

- **Files, folders, versions, and a trash** that holds things for 30 days.
- **Share a link** with anyone, with an optional password, an optional expiry,
  and view only or download. Change any of that later without the link
  changing.
- **Share with someone on your server** by tapping their face. No usernames to
  type. They keep access on every device they own.
- **Plug in a USB drive** and tap "Use this drive". Eject it safely from the
  app when you are done, or combine several drives into one big one.
- **Uploads survive a dropped connection.** They continue from the exact byte
  they stopped at, not from the beginning.
- **English and Arabic**, each with its own typeface and full right to left
  layout.

---

## Something not working?

| Problem | Answer |
| --- | --- |
| Browser says "Not secure" | Expected with no domain name. It is plain HTTP on your own network, not a broken certificate. See [HTTP and HTTPS](docs/self-hosting/https.mdx). |
| The app cannot find the server | Type the address instead. Both devices need to be on the same network. |
| The app says the server is unreachable | Check you did not type `https://`. With no domain it serves HTTP, and an HTTPS request fails during the handshake. |
| Forgot the admin password | Run `localdrive reset-admin` |
| A USB drive does not show up | Drive management needs Linux. On Windows or macOS, plug it in, then point Local Drive at the folder. |

More in [Troubleshooting](docs/self-hosting/troubleshooting.mdx), every command in
the [CLI reference](docs/self-hosting/cli.mdx), and every setting in
[Environment variables](docs/self-hosting/environment-variables.mdx).

---

## What it looks like

The files browser on desktop. Folders and files carry their own type colour,
and the badges say what is shared, starred, or kept on this device.

<img src="landing/public/showcase/app/app-files-desktop.png" alt="The Local Drive files browser on desktop" width="100%">

Every photo in one timeline, grouped by month and ordered by when it was taken
rather than when it was uploaded. The grid is masonry, so a panorama stays a
panorama instead of being cropped to a square.

<img src="landing/public/showcase/app/app-gallery.png" alt="The Local Drive gallery on desktop, a masonry grid grouped by month" width="100%">

These are screenshots of the running app, not mockups.

---

## For developers

| Folder | What it is |
| --- | --- |
| [`server/`](server/) | The Go backend. One binary, several modes. This is the product. |
| [`localdrive/`](localdrive/) | The Flutter app. One codebase, every platform. |
| [`docs/`](docs/) | The full documentation, rendered by the site. |
| [`landing/`](landing/) | The website, which reads `docs/` directly. |

```
cd server     && go test ./... && go vet ./...
cd localdrive && flutter analyze && flutter test
cd landing    && npm run build
```

Start with [Architecture overview](docs/architecture/overview.mdx) and
[Development setup](docs/contributing/development-setup.mdx).

| | |
| --- | --- |
| [Contributing](CONTRIBUTING.md) | How to get it running and what makes a change easy to accept. |
| [Code of conduct](CODE_OF_CONDUCT.md) | Be decent to people. |
| [Security policy](SECURITY.md) | How to report a vulnerability privately, and what is in scope. |
| [Disclaimer](DISCLAIMER.md) | What this is and is not built for. Worth reading before you trust it with anything. |
| [Notes for coding agents](AGENTS.md) | Context for an AI assistant working in this repository. |

---

## License

MIT. See [LICENSE](LICENSE).
