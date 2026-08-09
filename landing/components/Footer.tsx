import Link from "next/link";

import { Mark } from "@/components/brand/Mark";
import { GitHubIcon } from "@/components/ui/GitHubIcon";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

const groups = [
  {
    title: "Documentation",
    links: [
      { label: "Introduction", href: "/docs" },
      { label: "Quick start", href: "/docs/getting-started/quick-start" },
      { label: "Self hosting", href: "/docs/self-hosting/requirements" },
      { label: "Architecture", href: "/docs/architecture/overview" },
    ],
  },
  {
    title: "Features",
    links: [
      { label: "Sharing", href: "/docs/features/sharing" },
      { label: "Gallery", href: "/docs/features/gallery" },
      { label: "Transfers", href: "/docs/features/transfers" },
      { label: "Offline availability", href: "/docs/features/offline-availability" },
    ],
  },
  {
    title: "Project",
    links: [
      { label: "Changelog", href: "/changelog" },
      { label: "License", href: "/license" },
      { label: "Contributing", href: "/docs/contributing/development-setup" },
      { label: "Security", href: "/docs/architecture/security" },
    ],
  },
] as const;

/*
  No top margin here. Every page above ends with either its own bottom padding
  or its own rule, so a margin only put an empty band between two borders.
*/
export function Footer() {
  return (
    <footer className="border-t border-stroke">
      <div className="mx-auto max-w-6xl px-5 py-14 sm:px-7 lg:px-8">
        <div className="grid gap-10 md:grid-cols-[1.4fr_repeat(3,1fr)]">
          <div>
            <Link href="/" className="flex items-center gap-2.5 hover:opacity-80">
              <Mark size={26} />
              <span className="text-[17px] font-bold tracking-[-0.02em]">
                {site.name}
              </span>
            </Link>
            <p className="mt-4 max-w-xs text-[13px] leading-[18px] text-fg-secondary">
              {site.description}
            </p>
            {hasRepo && (
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noreferrer noopener"
                className="mt-5 inline-flex items-center gap-2 text-[13px] text-fg-secondary hover:text-fg"
              >
                <GitHubIcon size={16} />
                View source on GitHub
              </a>
            )}
          </div>

          {groups.map((group) => (
            <div key={group.title}>
              <h2 className="text-[11px] font-semibold uppercase tracking-[0.4px] text-fg-muted">
                {group.title}
              </h2>
              <ul className="mt-4 space-y-2.5">
                {group.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="text-[14px] text-fg-secondary hover:text-fg"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 flex flex-col gap-3 border-t border-stroke pt-7 text-[13px] text-fg-secondary sm:flex-row sm:items-center sm:justify-between">
          <p>
            Released under the{" "}
            <Link href="/license" className="text-fg hover:text-accent">
              MIT License
            </Link>
            .
          </p>
          <p>
            Made by{" "}
            <a
              href={site.author.url}
              target="_blank"
              rel="noreferrer noopener"
              className="font-semibold text-fg hover:text-accent"
            >
              {site.author.name}
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}
