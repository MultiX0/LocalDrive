import Link from "next/link";

import { Mark } from "@/components/brand/Mark";
import { NavLinks } from "@/components/NavLinks";
import { GitHubIcon } from "@/components/ui/GitHubIcon";
import { formatStars, getRepo } from "@/lib/github";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

/**
 * The one navigation bar, on every page.
 *
 * A server component, so the star count is fetched and cached at the edge
 * rather than by every visitor's browser.
 */
export async function Nav() {
  const repo = await getRepo();

  return (
    <header className="sticky top-0 z-50 border-b border-stroke bg-base/85 backdrop-blur-md">
      <div className="relative mx-auto flex h-16 max-w-6xl items-center gap-4 px-5 sm:gap-6 sm:px-7 lg:px-8">
        <Link
          href="/"
          className="flex items-center gap-2.5 hover:opacity-80"
          aria-label={`${site.name} home`}
        >
          <Mark size={26} />
          <span className="text-[17px] font-bold tracking-[-0.02em]">
            {site.name}
          </span>
        </Link>

        <NavLinks>
          {/*
            The repository link and its star count only exist once there is a
            repository. Before that this renders nothing at all, rather than a
            dead link or a zero that looks like real data.
          */}
          {hasRepo && (
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noreferrer noopener"
              className="flex items-center gap-2 rounded-pill border border-stroke bg-elevated px-3.5 py-2 text-[14px] font-semibold hover:border-fg-secondary sm:ml-2"
            >
              <GitHubIcon size={17} />
              <span className="sr-only">
                {site.name} on GitHub{repo ? `, ${repo.stars} stars` : ""}
              </span>
              {repo && (
                <span aria-hidden className="tabular-nums">
                  {formatStars(repo.stars)}
                </span>
              )}
            </a>
          )}
        </NavLinks>
      </div>
    </header>
  );
}
