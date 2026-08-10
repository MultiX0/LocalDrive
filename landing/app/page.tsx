import Image from "next/image";
import Link from "next/link";

import { Mark } from "@/components/brand/Mark";
import { DesktopFrame, PhoneFrame } from "@/components/showcase/AppFrame";

import { ShareDemo, TransfersDemo } from "@/components/showcase/TransfersDemo";
import { VerificationLoop } from "@/components/showcase/VerificationLoop";
import { GitHubIcon } from "@/components/ui/GitHubIcon";
import { PlatformRow } from "@/components/ui/PlatformIcons";
import { TerminalTabs } from "@/components/ui/TerminalTabs";
import { guides } from "@/lib/guides";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

export default function Home() {
  return (
    <>
      <Hero />
      <OneCommand />
      <Product />
      <Features />
      <Guides />
      <Footprint />
      <NotDoing />
      <Roadmap />
      <Ownership />
      <Verification />
      <ClosingCta />
    </>
  );
}

/* ------------------------------------------------------------------ hero */

function Hero() {
  return (
    <section className="hero-grid hero-glow relative border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 pb-16 pt-16 sm:px-7 sm:pt-24 lg:px-8">
        <div className="flex flex-col items-center text-center">
          <Mark size={84} animated title={`${site.name} logo`} />

          {/* what is true today, said once, where a launch banner usually goes */}
          <Link
            href="/guides"
            className="mt-8 inline-flex items-center gap-2 rounded-pill border border-stroke bg-elevated py-1.5 pl-2 pr-4 text-[13px] text-fg-secondary transition-colors duration-fast hover:border-accent hover:text-fg"
          >
            <span className="rounded-pill bg-accent px-2 py-0.5 text-[11px] font-semibold text-white">
              New
            </span>
            Step by step guides, with screenshots
            <span aria-hidden className="text-fg-muted">
              &rarr;
            </span>
          </Link>

          <h1 className="mt-7 max-w-3xl text-[38px] font-bold leading-[1.08] tracking-[-0.025em] sm:text-[56px] lg:text-[64px]">
            {site.tagline}
          </h1>

          {/*
            This line is not optional. PocketBase's version of the headline is
            literally true of one file; ours is a server binary plus a separate
            client, and this is what keeps the claim above it honest.
          */}
          <p className="mt-6 max-w-xl text-[16px] leading-[26px] text-fg-secondary sm:text-[18px] sm:leading-[28px]">
            {site.subhead}
          </p>

          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <Link
              href="/docs/getting-started/quick-start"
              className="rounded-pill bg-accent px-6 py-3 text-[15px] font-semibold hover:opacity-90"
            >
              Get started
            </Link>
            {hasRepo ? (
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noreferrer noopener"
                className="flex items-center gap-2 rounded-pill border border-stroke px-6 py-3 text-[15px] font-semibold hover:border-fg-secondary"
              >
                <GitHubIcon size={17} />
                Source
              </a>
            ) : (
              <Link
                href="/docs"
                className="rounded-pill border border-stroke px-6 py-3 text-[15px] font-semibold hover:border-fg-secondary"
              >
                Read the docs
              </Link>
            )}
          </div>

          {/*
            Three claims that can each be checked, rather than adjectives. The
            RAM figure is measured, the platform count is what the release
            workflow builds, and the telemetry claim is the absence of code.
          */}
          <dl className="mt-14 flex flex-col items-center gap-8 sm:flex-row sm:gap-14">
            {[
              { value: "1 GB", label: "of RAM is enough" },
              { value: "6", label: "platforms, one codebase" },
              { value: "0", label: "bytes of telemetry" },
            ].map((stat) => (
              <div key={stat.label} className="text-center sm:text-left">
                <dt className="text-[30px] font-bold leading-none tracking-[-0.03em] text-fg">
                  {stat.value}
                </dt>
                <dd className="mt-2 text-[13px] leading-[18px] text-fg-secondary">
                  {stat.label}
                </dd>
              </div>
            ))}
          </dl>
            <br />
          {/*
            One line, under the licence note rather than above the headline: it
            says how the thing is checked, which belongs after what the thing is.
            The mark is decorative because the sentence already names TestSprite.
          */}
          <p className="mt-3 flex items-center gap-2 text-[13px] text-fg-secondary">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/testsprite/mark.svg"
              alt=""
              aria-hidden
              width={15}
              height={15}
              className="shrink-0 opacity-90"
            />
            Tested with{" "}
            <a
              href="https://www.testsprite.com/"
              target="_blank"
              rel="noreferrer noopener"
              className="font-semibold text-accent transition-colors duration-fast hover:text-fg"
            >
              TestSprite
            </a>
          </p>
        </div>

        {/*
          The product, immediately, rather than three sections of claims first.

          This is a real screenshot of the running app against a fixture
          server, not a recreation. Every folder colour, type tone, badge and
          thumbnail is the app drawing itself.
        */}
        <div className="mt-16 sm:mt-20">
          <DesktopFrame className="mx-auto max-w-5xl">
            <Image
              src="/showcase/app/app-files-desktop.png"
              alt="The files browser on desktop, showing folders and files with their type colours"
              width={1440}
              height={900}
              priority
              className="w-full"
            />
          </DesktopFrame>
        </div>
      </div>
    </section>
  );
}

/* --------------------------------------------------------- one command */

function OneCommand() {
  return (
    <section className="border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <div className="grid min-w-0 gap-12 lg:grid-cols-[0.9fr_1.1fr] lg:gap-20">
          <div>
            <SectionLabel>Setup</SectionLabel>
            <h2 className="mt-4 text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
              One file, no configuration
            </h2>
            <p className="mt-5 max-w-md text-[15px] leading-[24px] text-fg-secondary">
              There is no configuration file to write first. On the first start
              the server generates its own secrets, mixing fresh randomness with
              an identifier unique to that machine, and writes them where it can
              read them again. Anything you do set in the environment always
              wins.
            </p>

            <ul className="mt-7 space-y-3">
              <Point>No database server, no Redis, no cgo</Point>
              <Point>Cross compiles to Windows, macOS and Linux on x86-64 and ARM64</Point>
              <Point>Designed to run on 1 GB of RAM</Point>
            </ul>
          </div>

          {/*
            One block with a choice at the top rather than two boxes stacked.
            Two terminals side by side made the page look like it wanted both
            run, which is the opposite of what it says.
          */}
          <TerminalTabs
            tabs={[
              {
                id: "binary",
                label: "The binary",
                lines: [
                  // the released file is called "server", not "localdrive", and
                  // a fresh download is not executable. showing anything else
                  // sends people to a command that does not exist.
                  { kind: "comment", text: "the file you downloaded is called server" },
                  { kind: "command", text: "chmod +x server" },
                  { kind: "command", text: "./server" },
                  { kind: "blank" },
                  { kind: "comment", text: "asks a few questions, then prints a QR code to scan" },
                  { kind: "output", text: "http://localhost:7443" },
                ],
                note: "On Windows, run server.exe instead. Nothing to install, no service to register, and deleting the file uninstalls it.",
              },
              {
                id: "docker",
                label: "Docker",
                lines: [
                  { kind: "command", text: "cd server" },
                  { kind: "command", text: "docker compose up -d" },
                  { kind: "blank" },
                  { kind: "comment", text: "no .env needed either way" },
                ],
                note: "Take this one if you want https and drive management handled for you.",
              },
            ]}
          />
        </div>
      </div>
    </section>
  );
}


/* ------------------------------------------------------------ features */

/**
 * Three things it does, each shown rather than described.
 *
 * A grid of six icon boxes is the shape every generated landing page takes,
 * and it says nothing: the icons are decoration and the sentences are
 * interchangeable. These are real screens instead, alternating sides so the
 * eye has somewhere to go.
 */
const featureRows = [
  {
    title: "Everyone in the house gets their own",
    body: "Invite people with a code. Each account has its own files, its own storage figure, and its own trash. An admin can see how much space someone is using and never what is in it.",
    points: [
      "They pick their own username and password",
      "Nothing is shared until somebody shares it",
      "Two factor, required for anyone who runs the server",
    ],
    image: "/guides/invite-3-code.png",
    alt: "The invite dialog showing a QR code and an invite code to send someone",
  },
  {
    title: "Send a file to someone with no account",
    body: "Make a link and send it however you already talk to them. Put a password on it, give it a date it stops working, or revoke it and it dies the moment you press the button.",
    points: [
      "Turn downloads off so it can only be viewed",
      "Expiry and password are two switches, not a setup",
      "Revoking is immediate, not a scheduled job",
    ],
    image: "/guides/share-3-link.png",
    alt: "The share dialog with a link, an allow download switch, expiry and password options",
  },
  {
    title: "Photos land in one timeline",
    body: "Anything you upload that is a picture or a clip shows up in the gallery, newest first, without filing it anywhere. Videos get a real frame from the video as their thumbnail.",
    points: [
      "Ordered by when it was taken, not when it was uploaded",
      "Full resolution when you open one, thumbnails until then",
      "Mark an album to keep on a device and it opens offline",
    ],
    image: "/guides/gallery-photos.png",
    alt: "The gallery showing uploaded photos in a continuous timeline",
  },
];

function Features() {
  return (
    <section className="border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>What you get</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          A drive for the people in your house
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-[24px] text-fg-secondary">
          Built for a home or a small team on one network, not for selling
          storage back to you by the month.
        </p>

        <div className="mt-20 space-y-24 lg:space-y-32">
          {featureRows.map((row, index) => (
            <div
              key={row.title}
              className="grid items-center gap-10 lg:grid-cols-2 lg:gap-16"
            >
              <div className={index % 2 === 1 ? "lg:order-2" : undefined}>
                <h3 className="text-[24px] font-bold leading-[1.2] tracking-[-0.02em] sm:text-[28px]">
                  {row.title}
                </h3>
                <p className="mt-5 text-[15px] leading-[25px] text-fg-secondary">
                  {row.body}
                </p>
                <ul className="mt-7 space-y-3">
                  {row.points.map((point) => (
                    <li
                      key={point}
                      className="flex items-start gap-3 text-[14px] leading-[22px] text-fg-secondary"
                    >
                      <svg
                        width="16"
                        height="16"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2.4"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden
                        className="mt-[3px] shrink-0 text-accent"
                      >
                        <path d="m5 12.5 4.5 4.5L19 7" />
                      </svg>
                      {point}
                    </li>
                  ))}
                </ul>
              </div>

              <div
                className={
                  index % 2 === 1
                    ? "lg:order-1 min-w-0"
                    : "min-w-0"
                }
              >
                <div className="overflow-hidden rounded-card border border-stroke bg-sunken">
                  <Image
                    src={row.image}
                    alt={row.alt}
                    width={2880}
                    height={1800}
                    className="h-auto w-full"
                    sizes="(min-width: 1024px) 560px, 100vw"
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ----------------------------------------------------------- closing cta */

/**
 * The page used to stop. Somebody who read the whole thing and decided they
 * want it should not have to scroll back up to find out how to start.
 */
function ClosingCta() {
  return (
    <section className="hero-grid relative border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-7 lg:px-8">
        <div className="flex flex-col items-center text-center">
          <h2 className="max-w-2xl text-[32px] font-bold leading-[1.12] tracking-[-0.025em] sm:text-[44px]">
            Put it on a machine tonight
          </h2>
          <p className="mt-5 max-w-lg text-[16px] leading-[26px] text-fg-secondary">
            One binary, no configuration file, and nothing to sign up for. If it
            is not for you, delete the folder and your files are still where you
            left them.
          </p>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <Link
              href="/docs/getting-started/quick-start"
              className="rounded-pill bg-accent px-6 py-3 text-[15px] font-semibold text-white hover:opacity-90"
            >
              Get started
            </Link>
            <Link
              href="/guides"
              className="rounded-pill border border-stroke px-6 py-3 text-[15px] font-semibold hover:border-fg-secondary"
            >
              See the guides
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------- guides */

/**
 * The visual guides, on the front page rather than buried.
 *
 * Most people never open documentation. They have one question, usually about
 * letting someone else in or sending a file to somebody who has no account, and
 * they want to see the screen rather than read about it.
 */
function Guides() {
  return (
    <section className="border-b border-stroke bg-sunken">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>Guides</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          How do I do this?
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-[24px] text-fg-secondary">
          Common questions, answered with a screenshot of every step.
        </p>

        {/*
          A list, not a grid of boxes. These are questions, and a question
          reads as a line you can run your eye down rather than a tile you have
          to stop and parse.
        */}
        <ul className="mt-12 border-t border-stroke">
          {guides.map((guide) => (
            <li key={guide.slug}>
              <Link
                href={`/guides/${guide.slug}`}
                className="group flex items-baseline gap-6 border-b border-stroke py-7 transition-colors duration-fast hover:border-fg-muted focus-visible:outline-none sm:gap-10"
              >
                <span className="hidden w-16 shrink-0 text-[12px] font-semibold uppercase tracking-[0.8px] text-fg-muted sm:block">
                  {guide.minutes} min
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-[19px] font-semibold leading-[26px] text-fg transition-colors duration-fast group-hover:text-accent sm:text-[22px] sm:leading-[30px]">
                    {guide.question}
                  </span>
                  <span className="mt-1.5 block text-[14px] leading-[22px] text-fg-secondary">
                    {guide.summary}
                  </span>
                </span>
                <span
                  aria-hidden
                  className="shrink-0 text-[18px] text-fg-muted transition-all duration-fast group-hover:translate-x-1 group-hover:text-accent"
                >
                  &rarr;
                </span>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------- product */

function Product() {
  return (
    <section className="border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>The apps</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          One codebase, every screen it runs on
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-[24px] text-fg-secondary">
          Phone, tablet, desktop and browser. Desktop is a different design
          rather than the phone stretched, which is the difference between an
          app that was ported and one that was built.
        </p>

        {/* what "every screen" actually means, before the screenshots of it */}
        <div className="mt-12 border-y border-stroke py-10">
          <PlatformRow />
        </div>

        {/* the gallery, full width, because photos are what a drive fills up with */}
        <div className="mt-14 min-w-0">
          <Figure caption="Every photo in one timeline, grouped by month and ordered by when it was taken rather than when it was uploaded.">
            <DesktopFrame title="Gallery">
              <Image
                src="/showcase/app/app-gallery.png"
                alt="The gallery on desktop, a masonry grid of photos grouped under month headings"
                width={1440}
                height={900}
                className="w-full"
                sizes="(min-width: 1024px) 72rem, 100vw"
              />
            </DesktopFrame>
          </Figure>
        </div>

        {/*
          The phones sit in their own band rather than in a column beside the
          desktop shot. A 390x844 screen next to a 1440x900 one makes a column
          roughly twice the height of the image it is aligned with, which is
          what pulled the old layout apart.
        */}
        <div className="mt-6 border-y border-stroke px-5 py-12 sm:px-10">
          <div className="mx-auto flex max-w-lg flex-wrap items-start justify-center gap-8 sm:gap-12">
            <figure className="w-[150px] shrink-0 sm:w-[190px]">
              <PhoneFrame>
                <Image
                  src="/showcase/app/app-gallery-mobile.png"
                  alt="The gallery on a phone"
                  width={780}
                  height={1688}
                  className="w-full"
                  sizes="190px"
                />
              </PhoneFrame>
              <figcaption className="mt-4 text-center text-[13px] leading-[20px] text-fg-secondary">
                The same timeline, on a phone
              </figcaption>
            </figure>

            <figure className="w-[150px] shrink-0 sm:w-[190px]">
              <PhoneFrame>
                <Image
                  src="/showcase/app/app-files-phone.png"
                  alt="The files browser on a phone"
                  width={390}
                  height={844}
                  className="w-full"
                  sizes="190px"
                />
              </PhoneFrame>
              <figcaption className="mt-4 text-center text-[13px] leading-[20px] text-fg-secondary">
                Files, laid out for a thumb
              </figcaption>
            </figure>
          </div>
        </div>

        {/*
          These two are drawn rather than captured. Both need state a fixture
          server cannot sit still in: a transfer part way through, and a share
          sheet mid decision. They mirror the real screens exactly, and the
          screenshots above are the honest anchor for them.
        */}
        <div className="mt-6 grid min-w-0 gap-6 lg:grid-cols-2">
          <Figure caption="A transfer is never silent. Every row says what it is doing, and a failure names its actual reason.">
            <DesktopFrame title="Transfers">
              <TransfersDemo />
            </DesktopFrame>
          </Figure>

          <Figure caption="Sharing with a person is a tap on a face. Nothing here is a text field, so nobody types a username.">
            <DesktopFrame title="Share">
              <ShareDemo />
            </DesktopFrame>
          </Figure>
        </div>
      </div>
    </section>
  );
}

/* --------------------------------------------------------- footprint */

/*
  The memory figure is measured, not estimated: a 0.0.1 build serving
  requests on Windows 11, read with Get-Process. Stated with the machine
  attached rather than as a benchmark, since one number from one machine
  isn't a benchmark.

  No competitor figures appear here. Comparing architectures is fair and
  checkable; publishing memory numbers for software nobody here measured
  is not.
*/
function Footprint() {
  return (
    <section className="border-t border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>Footprint</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          It runs on a machine you already have
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-[24px] text-fg-secondary">
          One process, holding a few megabytes. No database server, no PHP, no
          background workers to keep alive. An old laptop or a Raspberry Pi with
          1 GB of RAM is not a compromise here, it is the target.
        </p>

        {/*
          Two figures and a list, set as type rather than parked in boxes. The
          numbers are the point, so they get the size, and a hairline does the
          separating that a border used to.
        */}
        <div className="mt-16 grid min-w-0 gap-14 lg:grid-cols-2 lg:gap-20">
          <div>
            <p className="text-[13px] font-semibold uppercase tracking-[0.08em] text-fg-muted">
              Memory in use
            </p>
            <p className="mt-6 text-[72px] font-bold leading-none tracking-[-0.04em] text-fg sm:text-[88px]">
              18.7
              <span className="ml-3 text-[24px] font-semibold text-fg-secondary">
                MB
              </span>
            </p>
            <div className="mt-8">
              <div className="h-1 w-full overflow-hidden bg-stroke">
                <div className="h-full w-[2%] min-w-[6px] bg-accent" />
              </div>
              <div className="mt-3 flex justify-between text-[12px] text-fg-muted">
                <span>18.7 MB used</span>
                <span>1 GB of RAM</span>
              </div>
            </div>
            <p className="mt-7 max-w-md text-[14px] leading-[22px] text-fg-secondary">
              A 0.0.1 build serving requests, measured on Windows 11. The
              container ships with a 512 MB limit, about twenty five times more
              headroom than it uses.
            </p>
          </div>

          <div>
            <p className="text-[13px] font-semibold uppercase tracking-[0.08em] text-fg-muted">
              What it needs installed
            </p>
            <div className="mt-6">
              <Requirement label="A runtime" value="None" />
              <Requirement label="A database server" value="None" />
              <Requirement label="A web server" value="None" />
              <Requirement label="Shared libraries" value="None" />
              <Requirement label="Files to download" value="One, 20 MB" />
            </div>
            <p className="mt-7 max-w-md text-[14px] leading-[22px] text-fg-secondary">
              The usual self hosted drive is four or five services that have to
              agree with each other. This is one file. It builds with
              <code className="mx-1 border border-stroke bg-sunken px-1.5 py-0.5 text-[13px] text-fg">
                CGO_ENABLED=0
              </code>
              against a pure Go SQLite driver, so there is nothing to link
              against and nothing to keep in step.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

function Requirement({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-stroke pb-4 last:border-0 last:pb-0">
      <span className="text-[14px] text-fg-secondary">{label}</span>
      <span className="text-[14px] font-semibold text-fg">{value}</span>
    </div>
  );
}

function Roadmap() {
  return (
    <section className="border-t border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>On the roadmap</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          Search inside your videos, on your own machine
        </h2>
        <p className="mt-5 max-w-2xl text-[15px] leading-[24px] text-fg-secondary">
          Today you search file names. We are working on searching what is
          actually in them: every frame of every video, every photo, every
          document, indexed on the machine that holds them. Find the second
          somebody blew out the candles without remembering what you called the
          file.
        </p>

        <div className="mt-14 grid min-w-0 gap-14 lg:grid-cols-[1.1fr_0.95fr] lg:items-start lg:gap-20">
          <SemanticSearchIllustration />

          <div>
            <div className="space-y-5">
              <RoadmapPoint title="It never leaves the machine">
                The model runs where your files are. Nothing is uploaded, and
                there is no API key, because there is no third party involved.
              </RoadmapPoint>
              <RoadmapPoint title="Video, frame by frame">
                Indexed across time rather than as one thumbnail, so a search
                lands on the moment instead of the file.
              </RoadmapPoint>
              <RoadmapPoint title="Optional, and off by default">
                Indexing costs power and heat. It is something you switch on for
                the libraries you want it on.
              </RoadmapPoint>
            </div>

            {/* a rule rather than a rail, so it does not read as a fourth point */}
            <div className="mt-10 border-t border-stroke pt-7">
              <p className="max-w-md text-[14px] leading-[22px] text-fg-secondary">
                This is on the backlog, not in the product. It is a large piece
                of work and it happens faster if people want it.
              </p>
              {hasRepo ? (
                <Link
                  href={GITHUB_URL}
                  className="mt-5 inline-flex h-11 items-center gap-2 rounded-[24px] border border-stroke bg-sunken px-5 text-[14px] font-semibold text-fg transition-colors hover:border-accent hover:text-accent"
                >
                  <GitHubIcon size={16} />
                  Star it on GitHub
                </Link>
              ) : null}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function RoadmapPoint({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="border-l-2 border-stroke pl-5">
      <p className="text-[15px] font-semibold text-fg">{title}</p>
      <p className="mt-1.5 text-[14px] leading-[22px] text-fg-secondary">
        {children}
      </p>
    </div>
  );
}

/*
  Drawn, not captured, because the feature does not exist yet. It shows a
  query and a filmstrip with one frame matched, which is the shape of the
  idea without implying a build anyone can run.
*/
function SemanticSearchIllustration() {
  // real stills rather than empty boxes, so the row reads as a video and the
  // one that matches is visibly the one with candles in it. CC0, credited in
  // public/showcase/frames/CREDITS.md
  const frames = [
    { at: "0:04", src: "balloons", alt: "Party balloons", match: false },
    { at: "0:12", src: "gift", alt: "A wrapped present", match: false },
    { at: "0:21", src: "cake", alt: "A birthday cake with lit candles", match: true },
    { at: "0:33", src: "party", alt: "People at a birthday party", match: false },
    { at: "0:47", src: "slice", alt: "A slice of cake on a plate", match: false },
  ];

  return (
    <div className="min-w-0">
      <p className="mb-5 text-[11px] font-semibold uppercase tracking-[1.1px] text-fg-muted">
        What it would look like
      </p>

      {/* the field keeps its border, because it is a field. Nothing else here
          needs one. */}
      <div className="flex items-center gap-3 rounded-[12px] border border-stroke bg-sunken px-4 py-3.5">
        <svg
          width="16"
          height="16"
          viewBox="0 0 16 16"
          fill="none"
          aria-hidden="true"
          className="shrink-0 text-fg-muted"
        >
          <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
          <path
            d="M10.5 10.5L14 14"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
          />
        </svg>
        <span className="text-[14px] text-fg">
          birthday cake, candles
        </span>
      </div>

      <p className="mt-5 text-[12px] uppercase tracking-[0.08em] text-fg-muted">
        summer-2025.mp4
      </p>

      <div className="mt-3 flex gap-2.5">
        {frames.map((frame) => (
          <div key={frame.at} className="min-w-0 flex-1">
            <div
              className={`relative aspect-square overflow-hidden rounded-[8px] border ${
                frame.match ? "border-accent" : "border-stroke"
              }`}
            >
              <Image
                src={`/showcase/frames/${frame.src}.jpg`}
                alt={frame.alt}
                fill
                sizes="(min-width: 1024px) 120px, 18vw"
                className={`object-cover ${
                  // the misses are dimmed so the match is obvious at a glance
                  frame.match ? "" : "opacity-40 saturate-50"
                }`}
              />
            </div>
            <p
              className={`mt-2 text-center text-[11px] ${
                frame.match ? "font-semibold text-accent" : "text-fg-muted"
              }`}
            >
              {frame.at}
            </p>
          </div>
        ))}
      </div>

      <p className="mt-5 text-[13px] leading-[20px] text-fg-secondary">
        One match at 0:21, in a video nobody tagged.
      </p>
    </div>
  );
}

/* --------------------------------------------------------- not doing */

// taken near-verbatim from the introduction in the documentation
function NotDoing() {
  const items = [
    {
      title: "Not a sync client",
      body: "Files live on the server and are handed to clients on request. Offline availability is a per device choice, not a whole disk mirror.",
    },
    {
      title: "Not a peer to peer beam",
      body: "Sharing goes through the server so the other person still has access next week from a different device. That is the point of a Drive rather than Bluetooth.",
    },
    {
      title: "Not a folder you write into",
      body: "Storage is content addressed, so writing into the backing directory from outside the app is unsupported, the same way you cannot add a file to Google Drive by writing into its bucket.",
    },
  ];

  return (
    <section className="border-b border-stroke bg-sunken">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <SectionLabel>Scope</SectionLabel>
        <h2 className="mt-4 max-w-2xl text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
          What it deliberately does not do
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-[24px] text-fg-secondary">
          Three things people expect and will not find, said here rather than
          discovered a week in.
        </p>

        {/*
          A definition list, term on the left and the answer on the right. Three
          equal columns of prose is the shape of a page that has nothing to say
          and is padding it out to a row.
        */}
        <dl className="mt-14 border-t border-stroke">
          {items.map((item) => (
            <div
              key={item.title}
              className="flex flex-col gap-3 border-b border-stroke py-8 md:flex-row md:gap-14 md:py-9"
            >
              <dt className="shrink-0 text-[19px] font-bold leading-[26px] tracking-[-0.01em] text-fg md:w-[15rem] md:text-[21px] lg:w-[19rem]">
                {item.title}
              </dt>
              <dd className="max-w-2xl text-[15px] leading-[25px] text-fg-secondary">
                {item.body}
              </dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------ ownership */

/* -------------------------------------------------------- verification */

/*
  The collaboration section.

  Structured the way TestSprite structures their own explanation, because it is
  the clearest description of what the tool does: three properties, then four
  steps, then the loop. The content is entirely Local Drive's own, and every
  number and command in it is real. Their marketing figures are theirs and are
  not repeated here as though they were ours.
*/

function Verification() {
  const pillars = [
    {
      title: "It uses the app, it does not read it",
      body: "A real browser signs in, uploads a file and opens the share sheet against a running server. Nothing is mocked, so a screen that renders before its data arrives fails here and nowhere else.",
    },
    {
      title: "A failure arrives explained",
      body: "The failing step, the DOM around it, the test source and a root cause hypothesis come back as one bundle. There is nothing to reconstruct from scattered logs.",
    },
    {
      title: "Coverage compounds",
      body: "A test written to chase one bug stays in the suite afterwards. Fifteen of them now cover signing in, uploads, sharing and the API contract.",
    },
  ];

  const steps = [
    {
      n: "01",
      title: "Install and connect",
      body: (
        <>
          One global install and a key from the dashboard. Or the MCP server, in
          Claude Code, Cursor or Codex.
        </>
      ),
      code: "npm i -g @testsprite/testsprite-cli",
    },
    {
      n: "02",
      title: "Point it at a deployment",
      body: (
        <>
          Two projects, because Local Drive is two things: the web client and the
          Go API. It explores the running product rather than the source.
        </>
      ),
      code: "testsprite project create --type frontend",
    },
    {
      n: "03",
      title: "Run the workflows",
      body: (
        <>
          Ten plans written as sentences, five checks on the API contract. Kept in{" "}
          <code className="text-fg">e2e/testsprite/</code> and reviewed like any
          other code.
        </>
      ),
      code: "testsprite test run --all --wait",
    },
    {
      n: "04",
      title: "Fix, rerun, keep",
      body: (
        <>
          Read the bundle, fix the application rather than the test, replay it.
          The passing test stays.
        </>
      ),
      code: "testsprite test rerun <id> --wait",
    },
  ];

  return (
    <section className="border-b border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        <div className="max-w-2xl">
          <SectionLabel>Verification</SectionLabel>
          <h2 className="mt-4 text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
            Unit tests prove the pieces.
            <br />
            <span className="text-fg-secondary">
              Something has to prove the product.
            </span>
          </h2>
          <p className="mt-5 text-[15px] leading-[24px] text-fg-secondary">
            A screen can sit empty because the client calls a route the server
            does not serve, and from inside the code nothing is wrong: the types
            line up, the tests pass, the error is caught. Local Drive is tested
            end to end with{" "}
            <a
              href="https://www.testsprite.com/"
              target="_blank"
              rel="noreferrer noopener"
              className="text-fg underline decoration-stroke underline-offset-4 transition-colors hover:decoration-fg-secondary"
            >
              TestSprite
            </a>
            , which drives a real browser against a deployed server and found
            exactly that bug in this repository.
          </p>
        </div>

        {/* three properties, the reason this layer is not just another runner */}
        <div className="mt-12 grid gap-px overflow-hidden rounded-card border border-stroke bg-stroke sm:grid-cols-3">
          {pillars.map((item) => (
            <div key={item.title} className="bg-base p-6">
              <h3 className="text-[15px] font-semibold leading-[22px]">
                {item.title}
              </h3>
              <p className="mt-2.5 text-[13.5px] leading-[21px] text-fg-secondary">
                {item.body}
              </p>
            </div>
          ))}
        </div>

        {/* four steps, in their numbering */}
        <div className="mt-6 grid gap-px overflow-hidden rounded-card border border-stroke bg-stroke sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step) => (
            <div key={step.n} className="flex flex-col bg-base p-6">
              <span className="font-mono text-[11px] font-semibold uppercase tracking-[1px] text-accent">
                Step // {step.n}
              </span>
              <h3 className="mt-3 text-[15px] font-semibold leading-[22px]">
                {step.title}
              </h3>
              <p className="mt-2 flex-1 text-[13.5px] leading-[21px] text-fg-secondary">
                {step.body}
              </p>
              <code className="mt-4 block overflow-x-auto rounded-chip border border-stroke bg-sunken px-3 py-2 font-mono text-[11.5px] leading-[18px] text-fg-secondary">
                {step.code}
              </code>
            </div>
          ))}
        </div>

        <div className="mt-14">
          <h3 className="text-[19px] font-semibold tracking-[-0.01em]">
            The loop, as it actually ran here
          </h3>
          <p className="mt-2 max-w-2xl text-[14px] leading-[22px] text-fg-secondary">
            Six stages from one change to this repository. Every command and every
            line of output below is real.
          </p>
          <div className="mt-7">
            <VerificationLoop />
          </div>
        </div>

        {/* one engine, the surfaces this project actually uses */}
        <div className="mt-14 grid gap-px overflow-hidden rounded-card border border-stroke bg-stroke sm:grid-cols-3">
          {[
            {
              label: "CLI",
              for: "For agents and for people",
              body: "The primary interface, and what the committed suite runs on. Machine readable output and exit codes that mean something.",
            },
            {
              label: "MCP",
              for: "In the editor",
              body: "The one interface that reaches an app running only on your machine, which for a self hosted project is most of the time.",
            },
            {
              label: "Web portal",
              for: "The account",
              body: "Keys, project credentials and the dashboard a run links back to.",
            },
          ].map((surface) => (
            <div key={surface.label} className="bg-base p-6">
              <div className="flex items-baseline gap-2.5">
                <span className="text-[15px] font-semibold">{surface.label}</span>
                <span className="text-[12px] text-fg-muted">{surface.for}</span>
              </div>
              <p className="mt-2.5 text-[13.5px] leading-[21px] text-fg-secondary">
                {surface.body}
              </p>
            </div>
          ))}
        </div>

        <div className="mt-10 flex flex-col gap-5 border-t border-stroke pt-8 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/testsprite/mark.svg"
              alt=""
              aria-hidden
              width={30}
              height={30}
              className="shrink-0"
            />
            <p className="max-w-xl text-[13.5px] leading-[20px] text-fg-secondary">
              Local Drive is tested with{" "}
              <span className="text-fg">TestSprite</span>. Recommended, never
              required: the server does not call it, CI does not run it, and no
              key is needed to build, test or contribute.
            </p>
          </div>
          <div className="flex shrink-0 flex-col gap-2 self-start sm:items-end sm:self-auto">
            <Link
              href="/docs/contributing/testsprite"
              className="text-[14px] font-semibold text-accent transition-colors hover:text-fg"
            >
              How the suite is run &rarr;
            </Link>
            <a
              href="https://docs.testsprite.com/"
              target="_blank"
              rel="noreferrer noopener"
              className="text-[13px] text-fg-muted transition-colors hover:text-fg-secondary"
            >
              TestSprite documentation
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

function Ownership() {
  const claims = [
    {
      title: "Admin is not a master key",
      body: "An admin manages accounts, storage and settings. There is no admin bypass in the ownership query, so being one does not let you read anyone else's files.",
    },
    {
      title: "Permissions are enforced on the server",
      body: "Viewer, editor, owner, checked on every request. Something you cannot see returns a 404 rather than a 403, so the API never confirms that a file exists to someone with no access to it.",
    },
    {
      title: "No account with anyone",
      body: "No registration, no telemetry, no cloud dependency. People join by an invite code and pick their own password, which the admin never sees.",
    },
  ];

  return (
    <section>
      <div className="mx-auto max-w-6xl px-5 py-20 sm:px-7 lg:px-8">
        {/*
          The heading holds its own column and stays put while the claims
          scroll past it, so the three of them read as answers to the line on
          the left rather than as three tiles that happen to be adjacent.
        */}
        <div className="grid gap-12 lg:grid-cols-[0.85fr_1.15fr] lg:gap-20">
          <div className="lg:sticky lg:top-28 lg:self-start">
            <SectionLabel>Ownership</SectionLabel>
            <h2 className="mt-4 text-[30px] font-bold leading-[1.15] tracking-[-0.02em] sm:text-[38px]">
              Your hardware, and it behaves like it
            </h2>
            <p className="mt-5 max-w-md text-[15px] leading-[24px] text-fg-secondary">
              Three claims, each of them something you can go and check in the
              source rather than take our word for.
            </p>
          </div>

          <div className="border-t border-stroke">
            {claims.map((claim, index) => (
              <div
                key={claim.title}
                className="flex gap-6 border-b border-stroke py-8 sm:gap-10"
              >
                <span
                  aria-hidden
                  className="shrink-0 pt-1 text-[13px] font-bold tabular-nums tracking-[0.08em] text-accent"
                >
                  {String(index + 1).padStart(2, "0")}
                </span>
                <div className="min-w-0">
                  <h3 className="text-[19px] font-bold leading-[26px] tracking-[-0.01em] sm:text-[21px]">
                    {claim.title}
                  </h3>
                  <p className="mt-3 text-[15px] leading-[25px] text-fg-secondary">
                    {claim.body}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-16 flex flex-col gap-7 border-t border-stroke pt-10 sm:flex-row sm:items-center sm:gap-8">
          <div className="min-w-0 flex-1">
            <h3 className="text-[19px] font-bold tracking-[-0.01em] sm:text-[20px]">
              The documentation is the whole thing
            </h3>
            <p className="mt-2.5 max-w-lg text-[15px] leading-[23px] text-fg-secondary">
              Architecture, the permission model, every environment variable,
              and what each platform can honestly promise.
            </p>
          </div>
          <Link
            href="/docs"
            className="shrink-0 self-start rounded-pill bg-accent px-6 py-3 text-[15px] font-semibold hover:opacity-90 sm:self-auto"
          >
            Read the docs
          </Link>
        </div>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------- pieces */

// eyebrow above a section heading. the rule and the dot give a grey word
// somewhere to sit instead of floating above the headline as a stray label
function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-2.5 text-[11px] font-semibold uppercase tracking-[1.1px] text-accent">
      <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-accent" />
      {children}
    </span>
  );
}

function Point({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-start gap-3 text-[14px] leading-[21px] text-fg-secondary">
      <svg
        className="mt-[3px] shrink-0"
        width="15"
        height="15"
        viewBox="0 0 24 24"
        aria-hidden
      >
        <path
          d="M5 12.5 L10 17.5 L19 6.5"
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth="2.4"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      {children}
    </li>
  );
}

function Figure({
  children,
  caption,
}: {
  children: React.ReactNode;
  caption: string;
}) {
  return (
    <figure>
      {children}
      <figcaption className="mt-4 text-[13px] leading-[19px] text-fg-secondary">
        {caption}
      </figcaption>
    </figure>
  );
}
