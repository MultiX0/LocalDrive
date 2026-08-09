import fs from "node:fs/promises";
import path from "node:path";

import matter from "gray-matter";

import { DOCS_BASE, DOCS_HOME_SLUG, SECTIONS } from "@/content/docs-nav";

/*
  Reading the documentation.

  The files live at ../docs, outside this project, and are read from there
  rather than copied in, so editing a page in docs/ updates the site directly
  and there is nothing to keep in sync.
*/

const DOCS_DIR = path.join(process.cwd(), "..", "docs");

export type Doc = {
  /** url path after /docs, for example "features/gallery" */
  slug: string;
  /** the folder, or "" for a root level page */
  section: string;
  title: string;
  description: string;
  position: number;
  /** the markdown body, frontmatter already removed */
  body: string;
  /** absolute path, for error messages that are actually useful */
  file: string;
};

let cache: Doc[] | null = null;

/**
 * Every document, sorted into reading order.
 *
 * Memoised in production so the directory walk happens once per build rather
 * than once per page. Deliberately not memoised in development, because an
 * fs read inside a server component does not trigger a refresh when the file
 * changes and a stale cache makes editing docs feel broken.
 */
export async function getDocs(): Promise<Doc[]> {
  if (cache && process.env.NODE_ENV === "production") return cache;

  const files = await walk(DOCS_DIR);
  const docs: Doc[] = [];

  for (const file of files) {
    const raw = await fs.readFile(file, "utf8");
    const { data, content } = matter(raw);

    const relative = path
      .relative(DOCS_DIR, file)
      .split(path.sep)
      .join("/")
      .replace(/\.mdx?$/, "");

    const section = relative.includes("/") ? relative.split("/")[0] : "";

    // a page in a folder nobody named would otherwise appear under a
    // title-cased directory name, which is how "Api Reference" happens
    if (section && !SECTIONS[section]) {
      throw new Error(
        `docs: "${relative}" is in the folder "${section}", which has no label. ` +
          `Add it to landing/content/docs-nav.ts.`,
      );
    }

    if (typeof data.title !== "string" || !data.title.trim()) {
      throw new Error(`docs: "${relative}" has no title in its frontmatter.`);
    }

    docs.push({
      slug: relative,
      section,
      title: data.title.trim(),
      description:
        typeof data.description === "string" ? data.description.trim() : "",
      position:
        typeof data.sidebar_position === "number" ? data.sidebar_position : 999,
      body: content,
      file,
    });
  }

  docs.sort(compare);
  cache = docs;
  return docs;
}

/** Section order first, then position within the section, then title. */
function compare(a: Doc, b: Doc): number {
  const sectionA = a.section ? SECTIONS[a.section].position : a.position;
  const sectionB = b.section ? SECTIONS[b.section].position : b.position;
  if (sectionA !== sectionB) return sectionA - sectionB;
  if (a.position !== b.position) return a.position - b.position;
  return a.title.localeCompare(b.title);
}

async function walk(dir: string): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const found: string[] = [];

  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    // assets/ holds the mark, not prose
    if (entry.isDirectory() && entry.name !== "assets") {
      found.push(...(await walk(full)));
    } else if (entry.isFile() && /\.mdx?$/.test(entry.name)) {
      found.push(full);
    }
  }
  return found;
}

export async function getDoc(slug: string): Promise<Doc | null> {
  const docs = await getDocs();
  return docs.find((doc) => doc.slug === slug) ?? null;
}

/** The set of valid slugs, used to fail the build on a broken internal link. */
export async function getSlugs(): Promise<Set<string>> {
  return new Set((await getDocs()).map((doc) => doc.slug));
}

export type NavSection = {
  key: string;
  label: string;
  docs: Doc[];
};

/**
 * The sidebar: root level pages grouped under no heading, everything else
 * under its section label, all in reading order.
 */
export async function getNav(): Promise<NavSection[]> {
  const docs = await getDocs();
  const sections: NavSection[] = [];

  for (const doc of docs) {
    const key = doc.section;
    let section = sections.find((candidate) => candidate.key === key);
    if (!section) {
      section = {
        key,
        label: key ? SECTIONS[key].label : "",
        docs: [],
      };
      sections.push(section);
    }
    section.docs.push(doc);
  }
  return sections;
}

/** The href for a slug, collapsing the home page onto /docs itself. */
export function hrefFor(slug: string): string {
  return slug === DOCS_HOME_SLUG ? DOCS_BASE : `${DOCS_BASE}/${slug}`;
}

/** The previous and next documents in reading order, for the page footer. */
export async function getNeighbours(
  slug: string,
): Promise<{ previous: Doc | null; next: Doc | null }> {
  const docs = await getDocs();
  const index = docs.findIndex((doc) => doc.slug === slug);
  if (index < 0) return { previous: null, next: null };
  return {
    previous: docs[index - 1] ?? null,
    next: docs[index + 1] ?? null,
  };
}
