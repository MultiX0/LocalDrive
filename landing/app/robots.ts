import type { MetadataRoute } from "next";

import { site } from "@/lib/site";

/**
 * Crawling rules.
 *
 * Everything is open except the two routes that exist for the build rather
 * than for readers. Nothing here tries to block AI crawlers: this is
 * documentation for open source software, and being read by a model that then
 * answers someone's question about self hosting is the point, not a leak.
 * `llms.txt` exists for exactly that reason.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        // the social card source, and Next's own internals
        disallow: ["/og-preview", "/_next/"],
      },
    ],
    sitemap: `${site.url}/sitemap.xml`,
    host: site.url,
  };
}
