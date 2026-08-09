import type { Element, Nodes as HastNodes, Root as HastRoot } from "hast";
import type { Root as MdastRoot } from "mdast";

import GithubSlugger from "github-slugger";
import rehypeAutolinkHeadings, {
  type Options as AutolinkOptions,
} from "rehype-autolink-headings";
import rehypePrettyCode from "rehype-pretty-code";
import rehypeSanitize from "rehype-sanitize";
import rehypeSlug from "rehype-slug";
import rehypeStringify from "rehype-stringify";
import remarkGfm from "remark-gfm";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import { unified } from "unified";
import { visit } from "unist-util-visit";

import { DOCS_BASE, DOCS_HOME_SLUG } from "@/content/docs-nav";

/*
  Turning a documentation file into HTML.

  Parsed as CommonMark, not MDX, on purpose. There is no JSX and there are no
  expressions in any of these files, so MDX buys nothing, and it would treat a
  future `{MAX_UPLOAD}` written in ordinary prose as an expression and break
  the build. Markdown is the safer reading of what these files actually are.

  Highlighting is done here at build time by Shiki, which inlines colours as
  style attributes. That means no highlighting library and no theme stylesheet
  ever reach the browser.
*/

export type TocEntry = { depth: 2 | 3; id: string; text: string };

/**
 * A "#" appended to every heading, invisible until the heading is hovered or
 * the link itself is focused. Hidden from assistive tech because the heading
 * text right beside it already says where the link goes.
 */
const autolinkOptions: AutolinkOptions = {
  behavior: "append",
  properties: {
    className: ["heading-anchor"],
    "aria-hidden": "true",
    tabIndex: -1,
  },
};

export type Rendered = {
  html: string;
  toc: TocEntry[];
};

type RenderOptions = {
  /** the document's own slug, so relative links resolve from the right place */
  slug: string;
  /** every known slug, so a broken internal link fails the build */
  knownSlugs: Set<string>;
};

export async function renderDoc(
  markdown: string,
  { slug, knownSlugs }: RenderOptions,
): Promise<Rendered> {
  const toc: TocEntry[] = [];

  const file = await unified()
    .use(remarkParse)
    // the docs lean on tables heavily. endpoints.mdx is close to half table
    .use(remarkGfm)
    .use(remarkStripLeadingH1)
    .use(remarkDocsLinks, { slug, knownSlugs })
    .use(remarkRehype)
    .use(rehypeSlug)
    .use(rehypeAutolinkHeadings, autolinkOptions)
    .use(rehypeCollectToc, { toc })
    .use(rehypeTableScroller)
    .use(rehypePrettyCode, {
      theme: "github-dark-default",
      // 57 of the 60 code fences carry no language. without a default the
      // highlighter throws, and guessing the language from the content would
      // mislabel the project's own documentation
      defaultLang: "plaintext",
      // the block takes its background from the brand tokens instead
      keepBackground: false,
    })
    .use(rehypeStringify)
    .process(markdown);

  return { html: String(file), toc };
}

/**
 * Release notes from GitHub, which arrive over the network and are therefore
 * not trusted the way the in-repo docs are. Same look, plus sanitisation.
 */
export async function renderUntrusted(markdown: string): Promise<string> {
  const file = await unified()
    .use(remarkParse)
    .use(remarkGfm)
    .use(remarkRehype)
    .use(rehypeSanitize)
    .use(rehypeStringify)
    .process(markdown);
  return String(file);
}

/*
  Every document opens with an H1 that repeats its own frontmatter title. The
  page header already renders the title, so left alone every page shows it
  twice. Dropping it here fixes all 25 in one place rather than editing 25
  files, and keeps them portable to any other renderer.
*/
function remarkStripLeadingH1() {
  return (tree: MdastRoot) => {
    const first = tree.children[0];
    if (first?.type === "heading" && first.depth === 1) {
      tree.children.shift();
    }
  };
}

/*
  Internal links.

  The docs use three styles, all without a file extension:
    /features/gallery              absolute from the docs root
    ./features/gallery             relative to this file's folder
    ../self-hosting/backups        up one folder, then across

  All three have to land on the same place, and anything that does not resolve
  to a real page fails the build. A link checker in the pipeline is cheaper
  than discovering a broken link from a reader.
*/
function remarkDocsLinks({
  slug,
  knownSlugs,
}: {
  slug: string;
  knownSlugs: Set<string>;
}) {
  return (tree: MdastRoot) => {
    const folder = slug.includes("/") ? slug.split("/").slice(0, -1) : [];

    visit(tree, "link", (node) => {
      const url = node.url ?? "";

      // leave external links, anchors and mail alone, but make outbound links
      // announce themselves
      if (/^[a-z]+:/i.test(url) || url.startsWith("#")) {
        if (/^https?:/i.test(url)) {
          node.data = {
            ...node.data,
            hProperties: {
              ...(node.data?.hProperties ?? {}),
              target: "_blank",
              // rel is a token list in hast, not one string
              rel: ["noreferrer", "noopener"],
            },
          };
        }
        return;
      }

      const [rawPath, hash] = url.split("#");
      if (!rawPath) return;

      const clean = rawPath.replace(/\.mdx?$/, "").replace(/\/$/, "");
      let parts: string[];

      if (clean.startsWith("/")) {
        parts = clean.slice(1).split("/");
      } else {
        // resolve ./ and ../ against this document's own folder
        parts = [...folder];
        for (const segment of clean.split("/")) {
          if (segment === "." || segment === "") continue;
          if (segment === "..") parts.pop();
          else parts.push(segment);
        }
      }

      const target = parts.join("/");

      if (!knownSlugs.has(target)) {
        throw new Error(
          `docs: "${slug}" links to "${url}", which is not a documentation page. ` +
            `Resolved to "${target}".`,
        );
      }

      const base =
        target === DOCS_HOME_SLUG ? DOCS_BASE : `${DOCS_BASE}/${target}`;
      node.url = hash ? `${base}#${hash}` : base;
    });
  };
}

/** Collects h2 and h3 for the on-page contents. h4 only makes the rail noisy. */
function rehypeCollectToc({ toc }: { toc: TocEntry[] }) {
  const slugger = new GithubSlugger();

  return (tree: HastRoot) => {
    slugger.reset();
    visit(tree, "element", (node) => {
      if (node.tagName !== "h2" && node.tagName !== "h3") return;

      const text = textOf(node);
      if (!text) return;

      const id = node.properties.id ?? slugger.slug(text);
      toc.push({
        depth: node.tagName === "h2" ? 2 : 3,
        id: String(id),
        text,
      });
    });
  };
}

/*
  Tables have to be able to scroll on their own.

  The API reference has three column tables with long paths that overflow a
  phone. The usual fix is a gradient fade on the trailing edge, which this
  design system does not allow, so the wrapper gets a real border and its own
  scrollbar instead. The page itself must never scroll sideways.
*/
function rehypeTableScroller() {
  return (tree: HastRoot) => {
    visit(tree, "element", (node, index, parent) => {
      if (node.tagName !== "table" || !parent || index === undefined) return;
      if (parent.type === "element" && parent.tagName === "div") return;

      const wrapper: Element = {
        type: "element",
        tagName: "div",
        properties: { className: ["table-scroller"], tabIndex: 0 },
        children: [node],
      };
      parent.children[index] = wrapper;
    });
  };
}

function textOf(node: HastNodes): string {
  if (node.type === "text") return node.value;
  // the autolink plugin appends an anchor to every heading; its content is
  // decorative and must not end up in the contents rail
  if (node.type === "element") {
    const className = node.properties.className;
    if (Array.isArray(className) && className.includes("heading-anchor")) {
      return "";
    }
  }
  if (!("children" in node)) return "";
  return node.children.map(textOf).join("").trim();
}
