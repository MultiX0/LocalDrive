import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { Toc } from "@/components/docs/Toc";
import { DOCS_HOME_SLUG } from "@/content/docs-nav";
import { renderDoc } from "@/lib/docs/render";
import { getDoc, getDocs, getNeighbours, getSlugs, hrefFor } from "@/lib/docs/source";
import { site } from "@/lib/site";

type Params = { slug?: string[] };

/**
 * Every documentation page is generated at build time, which is why the
 * filesystem read never has to survive into production.
 */
export async function generateStaticParams(): Promise<Params[]> {
  const docs = await getDocs();
  return [
    // /docs itself, which renders the introduction
    { slug: [] },
    ...docs
      .filter((doc) => doc.slug !== DOCS_HOME_SLUG)
      .map((doc) => ({ slug: doc.slug.split("/") })),
  ];
}

export async function generateMetadata({
  params,
}: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { slug } = await params;
  const doc = await getDoc(slug?.join("/") || DOCS_HOME_SLUG);
  if (!doc) return {};

  return {
    title: doc.title,
    description: doc.description || site.description,
    openGraph: {
      title: `${doc.title} - ${site.name}`,
      description: doc.description || site.description,
      type: "article",
    },
  };
}

export default async function DocPage({
  params,
}: {
  params: Promise<Params>;
}) {
  const { slug } = await params;
  const requested = slug?.join("/") ?? "";

  // /docs and /docs/introduction are the same page. one canonical url, so the
  // sitemap has no duplicate pair
  if (requested === DOCS_HOME_SLUG) redirect("/docs");

  const doc = await getDoc(requested || DOCS_HOME_SLUG);
  if (!doc) notFound();

  const { html, toc } = await renderDoc(doc.body, {
    slug: doc.slug,
    knownSlugs: await getSlugs(),
  });
  const { previous, next } = await getNeighbours(doc.slug);

  return (
    <>
      <article className="min-w-0 py-10 lg:py-14">
        <header className="mb-10">
          <h1 className="text-[32px] font-bold leading-[38px] tracking-[-0.5px]">
            {doc.title}
          </h1>
          {doc.description && (
            <p className="mt-3 text-[17px] leading-[26px] text-fg-secondary">
              {doc.description}
            </p>
          )}
        </header>

        {/* the docs are in-repo and therefore trusted. release notes, which
            arrive over the network, go through a sanitising pipeline instead */}
        <div className="prose" dangerouslySetInnerHTML={{ __html: html }} />

        {/* two ruled rows rather than two boxes. Where you came from and where
            you are going is navigation, and navigation is a line */}
        <nav aria-label="Nearby pages" className="mt-16 border-t border-stroke">
          {previous && (
            <Link
              href={hrefFor(previous.slug)}
              className="group flex items-center gap-4 border-b border-stroke py-5"
            >
              <span
                aria-hidden
                className="shrink-0 text-[16px] text-fg-muted transition-all duration-fast group-hover:-translate-x-1 group-hover:text-accent"
              >
                &larr;
              </span>
              <span className="min-w-0">
                <span className="block text-[11px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
                  Previous
                </span>
                <span className="mt-1 block text-[16px] font-semibold text-fg transition-colors duration-fast group-hover:text-accent">
                  {previous.title}
                </span>
              </span>
            </Link>
          )}
          {next && (
            <Link
              href={hrefFor(next.slug)}
              className="group flex items-center justify-end gap-4 border-b border-stroke py-5 text-right"
            >
              <span className="min-w-0">
                <span className="block text-[11px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
                  Next
                </span>
                <span className="mt-1 block text-[16px] font-semibold text-fg transition-colors duration-fast group-hover:text-accent">
                  {next.title}
                </span>
              </span>
              <span
                aria-hidden
                className="shrink-0 text-[16px] text-fg-muted transition-all duration-fast group-hover:translate-x-1 group-hover:text-accent"
              >
                &rarr;
              </span>
            </Link>
          )}
        </nav>
      </article>

      <aside className="hidden py-14 xl:block">
        <div className="sticky top-24">
          <Toc entries={toc} />
        </div>
      </aside>
    </>
  );
}
