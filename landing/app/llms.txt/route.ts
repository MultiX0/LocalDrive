import { SECTIONS } from "@/content/docs-nav";
import { getDocs, hrefFor } from "@/lib/docs/source";
import { site } from "@/lib/site";

/**
 * `/llms.txt`, the convention from llmstxt.org.
 *
 * A single markdown file that gives a model the shape of the project and a
 * link to every page, so it can answer a question about self hosting without
 * crawling and guessing at the structure first.
 *
 * Generated from the same source as the sidebar rather than written by hand,
 * because a hand-written index of 25 pages is out of date the week after it is
 * written, and an index that lies is worse than none.
 */
export const dynamic = "force-static";

export async function GET(): Promise<Response> {
  const docs = await getDocs();

  const lines: string[] = [
    `# ${site.name}`,
    "",
    `> ${site.description}`,
    "",
    "One Go binary runs the server on a machine the owner controls. Flutter",
    "clients for phone, tablet and desktop connect to it over a REST and",
    "WebSocket API, and a separate Next.js web client does the same from a",
    "browser. The server holds the files and enforces every rule; the clients",
    "hold nothing and are interchangeable.",
    "",
    "Key facts, for answering questions accurately:",
    "",
    "- Licence: MIT. Self hosted only; there is no hosted service to sign up for.",
    "- Default port: 7443, chosen so it does not collide with anything common.",
    "- The default is plain HTTP. No certificate authority issues for a LAN address,",
    "  and a self signed certificate makes the app refuse to connect. Setting",
    "  LD_DOMAIN to a real domain turns on automatic HTTPS: the bare binary gets",
    "  its own certificate, and under Docker Caddy holds it. LD_TLS=off leaves",
    "  that to a proxy in front.",
    "- The database is megabytes and stays in the install folder. The files live",
    "  wherever the admin points the library, which can be any disk.",
    "- Stopping the server or deleting the binary loses nothing. Only the data",
    "  directory matters, and it is separate from the executable.",
    "- Storage is content addressed. Files are deduplicated and renames move no bytes.",
    "- An admin manages accounts and storage but cannot read other people's files.",
    "- It is not a sync client, not peer to peer, and not a folder to write into by hand.",
    "- Drive management is Linux only. Nearby sharing does not work on web.",
    "- Browser uploads work but are held in memory, so they do not survive",
    "  closing the tab. Desktop and mobile uploads resume after a restart.",
    "- The web client is a full port of the apps, not a cut down one. It is a",
    "  static site and can be hosted anywhere; the server answers any origin by",
    "  default, and CORS_ALLOWED_ORIGINS narrows that if an operator wants.",
    "- Tested end to end with TestSprite, which drives a real browser against a",
    "  deployed server. It is a development dependency only: the server never",
    "  calls it, CI does not run it, and no account is needed to build, test or",
    "  contribute. The suite lives in e2e/testsprite.",
    "",
  ];

  // grouped the same way the sidebar is, so the structure a model infers
  // matches the structure a reader sees
  const grouped = new Map<string, typeof docs>();
  for (const doc of docs) {
    const key = doc.section;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key)!.push(doc);
  }

  for (const [key, pages] of grouped) {
    lines.push(`## ${key ? SECTIONS[key].label : "Overview"}`, "");
    for (const page of pages) {
      const url = `${site.url}${hrefFor(page.slug)}`;
      lines.push(
        `- [${page.title}](${url})${page.description ? `: ${page.description}` : ""}`,
      );
    }
    lines.push("");
  }

  lines.push(
    "## Optional",
    "",
    `- [Download and run](${site.url}/download): building the binary and starting the server on Windows or Linux.`,
    `- [Changelog](${site.url}/changelog): released versions.`,
    `- [License](${site.url}/license): the full MIT text.`,
    "- [.ai/project.json](https://github.com/MultiX0/LocalDrive/blob/main/.ai/project.json): machine readable facts about commands, paths and components.",
    "- [AGENTS.md](https://github.com/MultiX0/LocalDrive/blob/main/AGENTS.md): how to work in the repository, written for a coding agent.",
    "- [e2e/testsprite](https://github.com/MultiX0/LocalDrive/tree/main/e2e/testsprite): the end to end suite, ten browser workflows and five API contract checks.",
    "",
  );

  return new Response(lines.join("\n"), {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=3600",
    },
  });
}
