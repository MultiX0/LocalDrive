import type { MetadataRoute } from "next";

import { getDocs, hrefFor } from "@/lib/docs/source";
import { site } from "@/lib/site";

/**
 * Every page, built from the same source the navigation is.
 *
 * Generated rather than listed by hand, so a documentation page added to
 * `docs/` is in the sitemap the moment it exists and a page removed leaves no
 * entry pointing at a 404.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const docs = await getDocs();

  const fixed: MetadataRoute.Sitemap = [
    { url: site.url, changeFrequency: "weekly", priority: 1 },
    { url: `${site.url}/download`, changeFrequency: "weekly", priority: 0.9 },
    { url: `${site.url}/docs`, changeFrequency: "weekly", priority: 0.8 },
    { url: `${site.url}/changelog`, changeFrequency: "weekly", priority: 0.6 },
    { url: `${site.url}/license`, changeFrequency: "yearly", priority: 0.3 },
  ];

  const pages: MetadataRoute.Sitemap = docs
    // the introduction is served at /docs, already listed above
    .filter((doc) => hrefFor(doc.slug) !== "/docs")
    .map((doc) => ({
      url: `${site.url}${hrefFor(doc.slug)}`,
      changeFrequency: "monthly" as const,
      priority: 0.7,
    }));

  return [...fixed, ...pages];
}
