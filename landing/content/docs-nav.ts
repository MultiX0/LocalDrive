/**
 * Section names and their order in the sidebar.
 *
 * Kept by hand because nothing else names the folders. The docs carry a
 * `sidebar_position` per page, but deriving a label from the directory name
 * gives "Api Reference" and "Self Hosting" instead of proper capitalisation.
 *
 * Root level pages interleave with these by their own `sidebar_position`,
 * which is why the numbers below have gaps: introduction is 1 and
 * localization is 6, and they slot into the same ordered list.
 *
 * A document in a folder not listed here is a build error rather than a silent
 * append, so the navigation cannot drift as pages are added.
 */
export const SECTIONS: Record<string, { label: string; position: number }> = {
  "getting-started": { label: "Getting started", position: 2 },
  features: { label: "Features", position: 3 },
  "self-hosting": { label: "Self hosting", position: 4 },
  architecture: { label: "Architecture", position: 5 },
  "api-reference": { label: "API reference", position: 7 },
  contributing: { label: "Contributing", position: 8 },
};

/** Where the docs are mounted on the site. */
export const DOCS_BASE = "/docs";

/** The page shown at /docs itself. */
export const DOCS_HOME_SLUG = "introduction";
