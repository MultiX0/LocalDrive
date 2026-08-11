/*
  Writes a search engine's ownership file into public/ at build time.

  Google hands you a file to upload and asks you never to remove it. Committing
  it would put a token that proves ownership of the domain into a public
  repository, and anyone could then see which properties are claimed. So the
  name lives in the host's environment instead, and the file is written during
  the build on whichever machine is deploying.

  Nothing here is required. With the variable unset this prints one line and
  exits, so a contributor cloning the repository builds exactly as before.

  Set on the host (Vercel, or wherever the site is deployed):

    SITE_VERIFICATION_FILE=google1234abcd.html

  The body is the one line Google puts in that file, derived from the name. If
  a provider ever hands you a file whose contents are not that, set it verbatim:

    SITE_VERIFICATION_BODY=whatever-the-file-actually-contains
*/

import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const name = (process.env.SITE_VERIFICATION_FILE ?? "").trim();

if (!name) {
  console.log("site verification: no SITE_VERIFICATION_FILE set, nothing to write");
  process.exit(0);
}

// a name is all this takes, so it must not be able to reach outside public/
if (name.includes("/") || name.includes("\\") || name.includes("..")) {
  console.error(`site verification: refusing a name with a path in it: ${name}`);
  process.exit(1);
}

const body = (process.env.SITE_VERIFICATION_BODY ?? `google-site-verification: ${name}`).trim();
const target = path.join(process.cwd(), "public", name);

await mkdir(path.dirname(target), { recursive: true });
await writeFile(target, `${body}\n`, "utf8");

console.log(`site verification: wrote public/${name}`);
