# The Local Drive website

The marketing page and the rendered documentation, in one Next.js app.

It reads `../docs` and `../LICENSE` directly at build time rather than keeping
copies. Editing a page in `docs/` updates the site, and the site cannot show
something the repository does not say.

## Running it

```
npm install
npm run dev
```

Editing a file under `../docs` needs a browser refresh rather than a restart.
An `fs` read inside a server component does not trigger hot reload, which is a
known trade for having one source of truth instead of two.

## Configuration

Everything is optional. With none of it set the site builds and looks
deliberate: the star count and repository links do not render at all, and the
changelog shows its own empty state.

| Variable | What it does |
| --- | --- |
| `NEXT_PUBLIC_GITHUB_REPO` | `owner/name`. Turns on the star count, source links, release downloads and the changelog. |
| `NEXT_PUBLIC_SITE_URL` | The public origin, used for absolute social card and sitemap URLs. |
| `GITHUB_TOKEN` | Optional, server only. Raises the API rate limit if traffic grows. |

## Layout

```
app/
  page.tsx                   the landing page
  download/                  build and run the binary, per platform
  docs/[[...slug]]/          every page in ../docs
  changelog/  license/       from GitHub releases, and from ../LICENSE
  og-preview/                the source for the social card, not for readers
  robots.ts  sitemap.ts  llms.txt/
components/
  brand/                     the mark, from the same geometry the app draws
  showcase/                  the drawn screens, for states a fixture cannot hold
  docs/  ui/
lib/
  docs/                      read ../docs, render it, check every link
  github.ts                  stars, releases, downloads, all failing softly
  site.ts                    names, the tagline, the configured repository
content/docs-nav.ts          section labels and their order
```

## The brand

Every colour, radius, duration and typeface in `app/globals.css` is transcribed
from the app's own design system in `../localdrive/lib/core/constants/`. If a
token changes there it changes here, and nowhere else.

Two rules the app enforces and this site inherits: **there are no shadows and
no gradients.** Every surface is a flat fill plus a one pixel border. Reaching
for either means it is off brand.

## The documentation pipeline

The files are parsed as CommonMark rather than MDX. There is no JSX in any of
them, and MDX would treat a future `{VALUE}` written in ordinary prose as an
expression and break the build for nothing.

Three things the content forces, all handled in `lib/docs/render.ts`:

- Every page opens with an H1 repeating its own frontmatter title, so one is
  stripped rather than editing 25 files.
- Internal links appear in three styles, absolute, `./` and `../`. All are
  rewritten, and **an unresolvable link fails the build** rather than becoming
  a 404 someone finds later.
- Most code fences carry no language, so the highlighter needs a default.
  Languages are never inferred from content; guessing mislabels the project's
  own documentation.

## Regenerating the social card

`public/og.png` is a screenshot of `/og-preview` at 1200 by 630. Rendering it
as a real page rather than composing it in an image library means it uses the
same tokens, typeface and mark as the rest of the site.

```
npm run build && npm start
# then screenshot /og-preview at 1200x630 into public/og.png
```

## Regenerating the app screenshots

The images under `public/showcase/app/` are the real Flutter app running
against the fixture server in `../capture`, not a recreation. See that folder
for how it works.
