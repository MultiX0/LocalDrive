/**
 * Everything about this site that is not content.
 *
 * The repository defaults to the real one and can be pointed elsewhere with
 * NEXT_PUBLIC_GITHUB_REPO, which is what a fork sets. Everything reading from
 * it still has to cope with getting nothing back: set the variable to an empty
 * string and the star count, release links and changelog fall back to their
 * empty states rather than breaking the build.
 */

/** "owner/name". Empty disables every feature that reads from GitHub. */
export const GITHUB_REPO = (
  process.env.NEXT_PUBLIC_GITHUB_REPO ?? "MultiX0/LocalDrive"
).trim();

export const hasRepo = GITHUB_REPO.length > 0 && GITHUB_REPO.includes("/");

export const GITHUB_URL = hasRepo ? `https://github.com/${GITHUB_REPO}` : "";

export const site = {
  name: "Local Drive",
  /*
    The headline echoes PocketBase on purpose. The line under it is not
    optional: PocketBase's claim is literally true of one file, and ours is a
    server binary plus a separate client. The subhead is what keeps the
    headline honest, so it travels with it everywhere the headline appears.
  */
  tagline: "Open source Drive in 1 file",
  subhead:
    "One Go binary runs the server on a machine you own. Apps for phone, tablet, desktop and browser connect to it.",
  description:
    "Local Drive is a private alternative to Google Drive that runs on hardware you own. No account with anyone, no subscription, and no company in the middle.",
  author: {
    name: "MultiX",
    url: "https://github.com/MultiX0",
  },
  /** Overridden by the deployment, used for absolute OG urls. */
  url: (process.env.NEXT_PUBLIC_SITE_URL ?? "https://localdrive.iprog.dev").replace(
    /\/$/,
    "",
  ),
} as const;

export const nav = [
  { label: "Guides", href: "/guides" },
  { label: "Download", href: "/download" },
  { label: "Docs", href: "/docs" },
  { label: "Changelog", href: "/changelog" },
  { label: "License", href: "/license" },
] as const;
