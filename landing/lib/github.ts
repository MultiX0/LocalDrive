import { GITHUB_REPO, hasRepo } from "./site";

/*
  Everything read from GitHub.

  Two rules run through all of it.

  First, nothing is invented. Local Drive has no public repository yet, so
  every one of these can legitimately return nothing, and the components that
  use them render nothing rather than a placeholder. A star count of zero on a
  project that has not launched reads as "nobody cares", which is worse than
  showing no number at all.

  Second, these run on the server. A token, if one is ever set, stays there.
  The browser never sees it and never talks to the GitHub API directly, which
  also means the rate limit is per deployment rather than per visitor.
*/

/** Long enough that a front page spike cannot exhaust the hourly rate limit. */
const REVALIDATE_SECONDS = 900;

const headers: HeadersInit = {
  Accept: "application/vnd.github+json",
  "X-GitHub-Api-Version": "2022-11-28",
  // optional. unauthenticated is 60 requests an hour per IP, which is fine at
  // this revalidation window, but a token raises it to 5000 if traffic grows
  ...(process.env.GITHUB_TOKEN
    ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }
    : {}),
};

async function api<T>(path: string): Promise<T | null> {
  if (!hasRepo) return null;

  try {
    const response = await fetch(`https://api.github.com/repos/${GITHUB_REPO}${path}`, {
      headers,
      next: { revalidate: REVALIDATE_SECONDS },
    });
    // a 404 is the expected answer before the repo exists, not an incident
    if (!response.ok) return null;
    return (await response.json()) as T;
  } catch {
    // the network, DNS, or GitHub being down. the site still renders
    return null;
  }
}

export type RepoInfo = {
  stars: number;
  forks: number;
  license: string | null;
};

export async function getRepo(): Promise<RepoInfo | null> {
  const data = await api<{
    stargazers_count: number;
    forks_count: number;
    license: { spdx_id: string } | null;
  }>("");
  if (!data) return null;

  return {
    stars: data.stargazers_count,
    forks: data.forks_count,
    license: data.license?.spdx_id ?? null,
  };
}

export type Release = {
  tag: string;
  name: string;
  body: string;
  publishedAt: string;
  url: string;
  prerelease: boolean;
};

export async function getReleases(): Promise<Release[]> {
  const data = await api<
    Array<{
      tag_name: string;
      name: string | null;
      body: string | null;
      published_at: string | null;
      html_url: string;
      prerelease: boolean;
      draft: boolean;
    }>
  >("/releases?per_page=30");

  if (!data) return [];

  return data
    // a draft is not published. it is visible to maintainers through the API
    // and would otherwise leak an unannounced version onto a public page
    .filter((release) => !release.draft)
    .map((release) => ({
      tag: release.tag_name,
      name: release.name?.trim() || release.tag_name,
      body: release.body?.trim() ?? "",
      publishedAt: release.published_at ?? "",
      url: release.html_url,
      prerelease: release.prerelease,
    }));
}

type ReleaseAsset = {
  name: string;
  url: string;
  size: number;
};

export type DownloadRow = {
  /** what a reader picks: "Windows", "Linux", "Android" */
  platform: string;
  /** the exact asset filename the release workflow produces */
  file: string;
  /** why this one, in a few words */
  note: string;
  asset: ReleaseAsset | null;
};

export type Downloads = {
  version: string;
  server: DownloadRow[];
  client: DownloadRow[];
  checksums: ReleaseAsset | null;
};

/*
  The release layout, matching .github/workflows/release.yml exactly.

  Filenames are fixed rather than pattern matched, so a release missing one
  shows that row as unavailable instead of silently dropping it. A reader
  looking for the Windows build and finding no row cannot tell whether it does
  not exist or whether the page is broken; a row that says so can.

  The two client desktop builds are archives, not bare executables, because
  Flutter produces a bundle directory on both platforms and a lone binary from
  inside one will not launch.
*/
const SERVER_FILES: Array<Omit<DownloadRow, "asset">> = [
  { platform: "Linux", file: "server", note: "x86-64, single file" },
  { platform: "Linux (ARM)", file: "server-arm64", note: "arm64, for a Pi or an ARM VPS" },
  { platform: "Windows", file: "server.exe", note: "x86-64, single file" },
];

const CLIENT_FILES: Array<Omit<DownloadRow, "asset">> = [
  { platform: "Android", file: "localdrive-client.apk", note: "install directly" },
  { platform: "Windows", file: "localdrive-client-setup.exe", note: "installer, recommended" },
  { platform: "Windows (portable)", file: "localdrive-client-windows.zip", note: "unzip and run, no install" },
  { platform: "Linux", file: "localdrive-client-linux.tar.gz", note: "extract and run" },
];

/**
 * The builds attached to the newest release, in a fixed order with a row for
 * every expected file whether or not it is there.
 */
export async function getDownloads(): Promise<Downloads | null> {
  const data = await api<
    Array<{
      tag_name: string;
      draft: boolean;
      prerelease: boolean;
      assets: Array<{ name: string; browser_download_url: string; size: number }>;
    }>
  >("/releases?per_page=10");

  if (!data) return null;

  const release =
    data.find((entry) => !entry.draft && !entry.prerelease) ??
    data.find((entry) => !entry.draft);
  if (!release) return null;

  const find = (file: string): ReleaseAsset | null => {
    const match = release.assets.find((asset) => asset.name === file);
    return match
      ? { name: match.name, url: match.browser_download_url, size: match.size }
      : null;
  };

  const rows = (list: Array<Omit<DownloadRow, "asset">>): DownloadRow[] =>
    list.map((row) => ({ ...row, asset: find(row.file) }));

  const server = rows(SERVER_FILES);
  const client = rows(CLIENT_FILES);

  // a release with none of the expected files is a release that predates this
  // naming, or one whose build failed. either way there is nothing to offer
  if (![...server, ...client].some((row) => row.asset)) return null;

  return {
    version: release.tag_name,
    server,
    client,
    checksums: find("SHA256SUMS"),
  };
}

/** Formats a star count the way GitHub itself does, so 1200 reads as 1.2k.
 * Exact below a thousand: "847" reads better than "0.8k". */
export function formatStars(count: number): string {
  if (count < 1000) return String(count);
  const thousands = count / 1000;
  return `${thousands >= 10 ? Math.round(thousands) : thousands.toFixed(1)}k`;
}
