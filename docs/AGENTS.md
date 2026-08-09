# Notes for coding agents: the documentation

Local rules for `docs/`. The root [`AGENTS.md`](../AGENTS.md) covers everything
general and is not repeated here.

This directory is the single source for all documentation. The website in
`landing/` reads it directly at build time, so there is nothing to copy and
nowhere for the two to disagree. Do not duplicate a page's content into a
README; link to it instead.

## The one rule

**Documentation describes what the software does, not what it should do.**

If you cannot run the command, do not document its output. If you are unsure
whether something behaves the same under Docker and as the bare binary, find
out before writing a sentence that covers both. Several pages exist because
that distinction was got wrong once.

Command output on these pages was captured from real runs. When you change
behaviour that appears in a captured block, recapture it rather than editing
the text by hand to what you expect.

## Format

- CommonMark, parsed as markdown, not MDX. Do not use JSX or `{expressions}`.
  A stray brace in prose is a parse failure for the whole build.
- Frontmatter is required: `title`, `description`, and `sidebar_position` where
  order matters. A file without a title fails the build.
- Every file opens with an H1 that matches its frontmatter title.
- Internal links have no file extension: `/features/gallery`,
  `./getting-started/quick-start` and `../self-hosting/backups` all work.
  **An internal link that does not resolve fails the build**, which is how
  broken cross references get caught.
- Most code fences carry no language tag and that is fine. Do not guess a
  language for a block that is showing terminal output.

## Structure

One directory per area. A new page goes in the directory it belongs to and gets
a `sidebar_position`, or it lands at the end of its section.

| Directory | For |
| --- | --- |
| `getting-started/` | First run, addresses, drives |
| `self-hosting/` | Running it: CLI, configuration, HTTPS, backups, updating, troubleshooting |
| `features/` | What the product does, from a user's point of view |
| `architecture/` | How it is built, for someone changing it |
| `api-reference/` | The HTTP surface |
| `contributing/` | Working on the project itself |

## Voice

Match what is already there. It is consistent, and it is the reason the pages
read as one document rather than thirty.

- Plain sentences. No marketing language, no exclamation marks, no emoji.
- Say the limitation. The pages that earn trust are the ones that state what
  does not work, and `introduction.mdx` has a "What it is not" section for
  exactly that reason.
- Prefer the concrete. A number, a path or a captured line beats an adjective.
- Do not tell the reader something is easy. Show the two commands instead.

## Checking your work

```
cd landing && npm run build
```

This parses every file here, resolves every internal link and fails on the
first problem. It is not optional for a documentation-only change, because it
is the only link checker the project has.
