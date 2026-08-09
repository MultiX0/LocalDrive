import type { Metadata } from "next";
import Link from "next/link";

import { PageHeader } from "@/components/ui/PageHeader";
import { getReleases } from "@/lib/github";
import { renderUntrusted } from "@/lib/docs/render";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Changelog",
  description: `Every released version of ${site.name}.`,
};

export default async function ChangelogPage() {
  const releases = await getReleases();

  return (
    <div className="mx-auto max-w-3xl px-5 py-14 sm:px-7 lg:px-8 lg:py-20">
      <PageHeader
        eyebrow="Releases"
        title="Changelog"
        lead="Every released version, newest first, taken from the tagged releases."
      />

      {releases.length === 0 ? <Empty /> : <Releases releases={releases} />}
    </div>
  );
}

/*
  Nothing to show. Does not distinguish "no releases yet" from "GitHub did
  not answer" -- to a reader both mean the same thing, and an API error
  message is noise on a page they came to for release notes.

  Returns 200 rather than 404 and stays in the sitemap: the page is correct,
  just early.
*/
function Empty() {
  return (
    <div className="border-t border-stroke pt-12">
      <h2 className="text-[24px] font-bold tracking-[-0.01em]">
        No releases yet
      </h2>
      <p className="mt-3 max-w-md text-[15px] leading-[24px] text-fg-secondary">
        The first tagged release will appear here automatically, with its notes.
        Until then you can run the current code from source.
      </p>
      <div className="mt-8 flex flex-wrap gap-3">
        <Link
          href="/docs/getting-started/quick-start"
          className="rounded-pill bg-accent px-5 py-2.5 text-[14px] font-semibold text-fg hover:opacity-90"
        >
          Quick start
        </Link>
        {hasRepo && (
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noreferrer noopener"
            className="rounded-pill border border-stroke px-5 py-2.5 text-[14px] font-semibold hover:border-fg-secondary"
          >
            View the repository
          </a>
        )}
      </div>
    </div>
  );
}

async function Releases({
  releases,
}: {
  releases: Awaited<ReturnType<typeof getReleases>>;
}) {
  // release notes arrive over the network, so unlike the in-repo docs they go
  // through a sanitising pipeline before being rendered
  const rendered = await Promise.all(
    releases.map(async (release) => ({
      ...release,
      html: release.body ? await renderUntrusted(release.body) : "",
    })),
  );

  return (
    <ol className="mt-12 space-y-14">
      {rendered.map((release) => (
        <li key={release.tag} className="scroll-mt-24" id={release.tag}>
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-[20px] font-semibold leading-[26px]">
              {release.name}
            </h2>
            {release.prerelease && (
              <span className="rounded-chip border border-warning px-2 py-0.5 text-[11px] font-semibold uppercase tracking-[0.4px] text-warning">
                Prerelease
              </span>
            )}
          </div>

          {release.publishedAt && (
            <time
              dateTime={release.publishedAt}
              className="mt-1.5 block text-[13px] text-fg-muted"
            >
              {new Date(release.publishedAt).toLocaleDateString("en", {
                year: "numeric",
                month: "long",
                day: "numeric",
              })}
            </time>
          )}

          {release.html ? (
            <div
              className="prose mt-5"
              dangerouslySetInnerHTML={{ __html: release.html }}
            />
          ) : (
            <p className="mt-5 text-[14px] text-fg-secondary">
              This release has no notes.
            </p>
          )}

          <a
            href={release.url}
            target="_blank"
            rel="noreferrer noopener"
            className="mt-5 inline-block text-[13px] text-accent hover:underline"
          >
            {release.tag} on GitHub
          </a>
        </li>
      ))}
    </ol>
  );
}
