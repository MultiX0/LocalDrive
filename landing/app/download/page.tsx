import type { Metadata } from "next";
import Link from "next/link";

import { PlatformTabs, Step } from "@/components/download/PlatformTabs";
import { PageHeader } from "@/components/ui/PageHeader";
import { Terminal } from "@/components/ui/Terminal";
import { type DownloadRow, type Downloads, getDownloads } from "@/lib/github";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Download and run",
  description:
    "Build the server binary, or download it, and run it on Windows or Linux.",
};

export default async function DownloadPage() {
  const downloads = await getDownloads();

  return (
    <div className="mx-auto max-w-3xl px-5 py-14 sm:px-7 lg:px-8 lg:py-20">
      <PageHeader
        eyebrow="Install"
        title="Download and run"
        lead="One binary. Build it yourself in two commands, or take a prebuilt one."
      />

      <WhatMatters />

      <Section title="Get the binary">
        {downloads ? (
          <Downloads downloads={downloads} />
        ) : (
          <NoBuildsYet />
        )}
      </Section>

      <Section title="Or build it yourself">
        <p className="mb-7 text-[15px] leading-[24px] text-fg-secondary">
          Two commands and about thirty seconds. You need{" "}
          <a
            href="https://go.dev/dl/"
            target="_blank"
            rel="noreferrer noopener"
            className="text-accent hover:underline"
          >
            Go 1.25
          </a>{" "}
          and nothing else. There is no C compiler in the way, because the
          SQLite driver is pure Go.
        </p>
        <PlatformTabs windows={<BuildWindows />} linux={<BuildLinux />} />
      </Section>

      <Section title="Start the server">
        <PlatformTabs windows={<RunWindows />} linux={<RunLinux />} />
      </Section>

      <Section title="The commands">
        <Commands />
      </Section>
    </div>
  );
}

/* ------------------------------------------------- what actually matters */

/*
  The framing, before any instructions.

  People arriving from a phone-app mental model assume the app is the product
  and the server is plumbing. Here it is the other way round, and getting that
  backwards leads to the wrong questions later: where files really live, who
  can read them, and what happens when a client is uninstalled.
*/
function WhatMatters() {
  return (
    <div className="border-l-2 border-accent pl-6 sm:pl-8">
      <h2 className="text-[22px] font-bold leading-[30px] tracking-[-0.01em]">
        The server is the product. The apps are just windows onto it.
      </h2>
      <div className="mt-4 space-y-3 text-[15px] leading-[24px] text-fg-secondary">
        <p>
          Everything lives in the server: your files, the accounts, the
          permissions, the versions, the sharing. Every rule is decided there
          and enforced there, on every request. This is the piece you install,
          the piece you back up, and the piece that is actually yours.
        </p>
        <p>
          The phone, desktop and browser apps hold nothing of their own. They
          ask the server what exists and show it. Uninstall every one of them
          and you have lost nothing, because none of them were ever where your
          files were. Point a fresh one at the same address and everything is
          there again.
        </p>
        <p className="text-fg">
          So if you only run one thing, run the server. You can reach it from a
          browser without installing any app at all.
        </p>
      </div>
    </div>
  );
}

/* --------------------------------------------------------------- builds */

function Downloads({ downloads }: { downloads: Downloads }) {
  return (
    <div>
      <p className="mb-8 text-[14px] text-fg-secondary">
        Version {downloads.version}.
      </p>

      <Group
        title="The server"
        blurb="Start here. One file, nothing to install. This is the piece that holds your files."
        rows={downloads.server}
      />

      <div className="mt-10">
        <Group
          title="The apps"
          blurb="Optional. Any browser reaches the server without installing anything, so take these only if you want a native app."
          rows={downloads.client}
        />
      </div>

      {downloads.checksums && (
        <p className="mt-8 text-[13px] text-fg-secondary">
          Verify what you downloaded against{" "}
          <a
            href={downloads.checksums.url}
            className="text-accent hover:underline"
          >
            SHA256SUMS
          </a>
          .
        </p>
      )}
    </div>
  );
}

function Group({
  title,
  blurb,
  rows,
}: {
  title: string;
  blurb: string;
  rows: DownloadRow[];
}) {
  return (
    <div>
      <h3 className="text-[16px] font-semibold">{title}</h3>
      <p className="mt-1.5 max-w-lg text-[13.5px] leading-[20px] text-fg-secondary">
        {blurb}
      </p>

      {/* ruled rows, not a boxed table. Each line is a thing you can take */}
      <div className="mt-5 border-t border-stroke">
        {rows.map((row) => (
          <div
            key={row.file}
            className="flex flex-wrap items-center gap-x-4 gap-y-3 border-b border-stroke py-4"
          >
            <div className="min-w-0 flex-1">
              <p className="text-[14px] font-semibold">{row.platform}</p>
              <p className="mt-0.5 font-mono text-[12px] text-fg-muted">
                {row.file}
                <span className="ml-2 font-sans">{row.note}</span>
              </p>
            </div>

            {row.asset ? (
              <a
                href={row.asset.url}
                className="shrink-0 rounded-pill bg-accent px-5 py-2 text-[13.5px] font-semibold hover:opacity-90"
              >
                Download
                <span className="ml-2 font-normal opacity-70">
                  {(row.asset.size / 1_048_576).toFixed(1)} MB
                </span>
              </a>
            ) : (
              /* the row stays, so a missing build reads as missing rather than
                 as a page that forgot this platform exists */
              <span className="shrink-0 rounded-pill border border-stroke px-5 py-2 text-[13.5px] text-fg-muted">
                Not in this release
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

/*
  There are no releases yet, so there is nothing to download.

  Rather than a disabled button or a "coming soon", this says so and sends
  people to the path that works right now. Building it is genuinely two
  commands, so this is not much of a consolation prize.
*/
function NoBuildsYet() {
  return (
    <div className="border-l-2 border-stroke pl-6">
      <h3 className="text-[19px] font-bold tracking-[-0.01em]">
        No prebuilt binaries yet
      </h3>
      <p className="mt-3 max-w-lg text-[15px] leading-[24px] text-fg-secondary">
        {site.name} has not cut a tagged release, so there is nothing signed to
        hand you. Build it from source below. It takes two commands and needs
        only Go.
      </p>
      <p className="mt-3 max-w-lg text-[15px] leading-[24px] text-fg-secondary">
        Tagging a version builds and attaches everything automatically, so
        download buttons appear here on their own the moment the first release
        exists.
      </p>
      {hasRepo && (
        <a
          href={`${GITHUB_URL}/releases`}
          target="_blank"
          rel="noreferrer noopener"
          className="mt-5 inline-block text-[13px] text-accent hover:underline"
        >
          Watch the releases page
        </a>
      )}
    </div>
  );
}

/* ---------------------------------------------------------------- build */

function BuildWindows() {
  return (
    <ol>
      <Step n={1} title="Get the code">
        <Terminal
          lines={[
            { kind: "command", text: "git clone https://github.com/MultiX0/LocalDrive.git" },
            { kind: "command", text: "cd LocalDrive\\server" },
          ]}
        />
      </Step>
      <Step n={2} title="Build it">
        <Terminal
          lines={[
            { kind: "command", text: "go build -o localdrive.exe ./cmd/localdrive" },
          ]}
        />
        <p className="mt-3 text-[14px] leading-[21px] text-fg-secondary">
          That produces <code className="text-fg">localdrive.exe</code> in the
          current folder. Move it wherever you like; it has no install
          directory and no registry keys.
        </p>
      </Step>
      <Step n={3} title="Check it runs">
        <Terminal lines={[{ kind: "command", text: ".\\localdrive.exe version" }]} />
      </Step>
    </ol>
  );
}

function BuildLinux() {
  return (
    <ol>
      <Step n={1} title="Get the code">
        <Terminal
          lines={[
            { kind: "command", text: "git clone https://github.com/MultiX0/LocalDrive.git" },
            { kind: "command", text: "cd LocalDrive/server" },
          ]}
        />
      </Step>
      <Step n={2} title="Build it">
        <Terminal
          lines={[
            { kind: "command", text: "CGO_ENABLED=0 go build -o localdrive ./cmd/localdrive" },
          ]}
        />
        <p className="mt-3 text-[14px] leading-[21px] text-fg-secondary">
          <code className="text-fg">CGO_ENABLED=0</code> makes the
          result a single static file that runs on any Linux with the same
          architecture, including inside a scratch container.
        </p>
      </Step>
      <Step n={3} title="Put it on your path">
        <Terminal
          lines={[
            { kind: "command", text: "sudo install -m 755 localdrive /usr/local/bin/" },
            { kind: "command", text: "localdrive version" },
          ]}
        />
      </Step>
    </ol>
  );
}

/* ------------------------------------------------------------------ run */

function RunWindows() {
  return (
    <ol>
      <Step n={1} title="Run it with no arguments">
        <Terminal
          lines={[
            { kind: "command", text: ".\\localdrive.exe" },
            { kind: "blank" },
            { kind: "comment", text: "double clicking the file does the same thing" },
          ]}
        />
        <p className="mt-3 text-[14px] leading-[21px] text-fg-secondary">
          With no arguments it runs setup. It asks five questions: where to keep
          things, whether to use Docker, which port, whether you have a domain,
          and an admin username and password.
        </p>
      </Step>
      <Step n={2} title="Let it generate its own secrets">
        <p className="text-[14px] leading-[21px] text-fg-secondary">
          You do not write a config file. It creates every secret on first
          start, mixing fresh randomness with an identifier unique to this
          machine, and saves them so a restart reuses the same ones. Anything
          you set in the environment always wins over what it generated.
        </p>
      </Step>
      <Step n={3} title="Open it">
        <Terminal
          lines={[
            { kind: "output", text: "https://localhost:7443" },
            { kind: "blank" },
            { kind: "comment", text: "it also prints a QR code to scan from a phone" },
          ]}
        />
        <p className="mt-3 text-[14px] leading-[21px] text-fg-secondary">
          Your browser warns once that the connection is not private. That is
          expected with no domain: the server made its own certificate, because
          no authority on the internet can vouch for a computer in your house.
        </p>
      </Step>
      <Step n={4} title="Keep it running">
        <Terminal
          lines={[
            { kind: "command", text: ".\\localdrive.exe status" },
            { kind: "command", text: ".\\localdrive.exe logs" },
          ]}
        />
      </Step>
    </ol>
  );
}

function RunLinux() {
  return (
    <ol>
      <Step n={1} title="Run it with no arguments">
        <Terminal
          lines={[
            { kind: "command", text: "localdrive" },
            { kind: "blank" },
            { kind: "comment", text: "asks five questions, then sets everything up" },
          ]}
        />
      </Step>
      <Step n={2} title="Let it generate its own secrets">
        <p className="text-[14px] leading-[21px] text-fg-secondary">
          No config file to write. Every secret is created on first start from
          fresh randomness mixed with a machine-unique identifier, then saved so
          restarts reuse them. Anything you set in the environment wins.
        </p>
      </Step>
      <Step n={3} title="Open it">
        <Terminal
          lines={[
            { kind: "output", text: "https://<your-ip>:7443" },
            { kind: "blank" },
            { kind: "comment", text: "a QR code is printed for scanning from a phone" },
          ]}
        />
      </Step>
      <Step n={4} title="Or run it in the foreground, with no Docker">
        <Terminal lines={[{ kind: "command", text: "localdrive serve" }]} />
        <p className="mt-3 text-[14px] leading-[21px] text-fg-secondary">
          Useful under systemd or in a terminal you are watching. You lose three
          things this way, cleanly and with no errors: HTTPS, drive management,
          and network discovery.
        </p>
      </Step>
      <Step n={5} title="Run it at boot">
        <Terminal
          lines={[
            { kind: "command", text: "sudo systemctl enable --now localdrive" },
            { kind: "blank" },
            { kind: "comment", text: "after writing a unit that runs: localdrive serve" },
          ]}
        />
      </Step>
    </ol>
  );
}

/* ------------------------------------------------------------- commands */

const COMMANDS = [
  ["(none)", "Set up and start a server. What you run the first time."],
  ["init", "Write a working configuration without asking anything."],
  ["serve", "Run the server in the foreground, with no Docker."],
  ["start", "Start an already configured server."],
  ["stop", "Stop a running server."],
  ["restart", "Restart a running server."],
  ["status", "Show whether the server is up, and where to reach it."],
  ["logs", "Follow the server log."],
  ["backup", "Write a backup of the database and the library."],
  ["reset-admin", "Reset the admin password on an existing install."],
  ["version", "Print the version."],
];

function Commands() {
  return (
    <>
      <p className="mb-5 text-[14px] leading-[21px] text-fg-secondary">
        The same binary in every mode. It is identical on Windows and Linux;
        only the way you invoke it differs.
      </p>
      <div className="overflow-x-auto">
        <table className="w-full text-[14px]">
          <thead>
            <tr className="border-b border-stroke">
              <th className="py-3 pr-6 text-left text-[11px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
                Command
              </th>
              <th className="py-3 text-left text-[11px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
                Does
              </th>
            </tr>
          </thead>
          <tbody>
            {COMMANDS.map(([name, summary]) => (
              <tr key={name} className="border-b border-stroke">
                <td className="whitespace-nowrap py-3 pr-6 font-mono text-fg">
                  {name}
                </td>
                <td className="py-3 text-fg-secondary">{summary}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-5 text-[14px] leading-[21px] text-fg-secondary">
        Every command takes <code className="text-fg">--dir</code> to point at a
        different install, and reads{" "}
        <code className="text-fg">LOCALDRIVE_HOME</code> for the same purpose.
        Full detail in{" "}
        <Link href="/docs/getting-started/quick-start" className="text-accent hover:underline">
          the quick start
        </Link>
        .
      </p>
    </>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-14 border-t border-stroke pt-10">
      <h2 className="mb-7 text-[22px] font-bold tracking-[-0.01em]">{title}</h2>
      {children}
    </section>
  );
}
