"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { nav } from "@/lib/site";

/**
 * The navigation links. Four labels plus the wordmark do not fit across a
 * 375 point screen, so below the small breakpoint they collapse into a menu
 * instead of overflowing or getting dropped.
 */
export function NavLinks({ children }: { children?: React.ReactNode }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // close the menu on navigation, including back/forward. Set during render
  // instead of an effect so the old menu never paints over the new page for
  // a frame.
  const [lastPath, setLastPath] = useState(pathname);
  if (lastPath !== pathname) {
    setLastPath(pathname);
    setOpen(false);
  }

  return (
    <>
      {/* wide enough to lay them out: all of them, inline */}
      <nav className="ml-auto hidden items-center gap-1 sm:flex" aria-label="Main">
        {nav.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            aria-current={pathname.startsWith(item.href) ? "page" : undefined}
            className="rounded-chip px-3 py-2 text-[14px] text-fg-secondary hover:bg-elevated hover:text-fg"
          >
            {item.label}
          </Link>
        ))}
        {children}
      </nav>

      {/* narrow: the repository link stays visible, the rest goes behind a
          button, because the source link is the one a visitor most often wants
          and it is also the smallest */}
      <div className="ml-auto flex items-center gap-2 sm:hidden">
        {children}
        <button
          type="button"
          onClick={() => setOpen((value) => !value)}
          aria-expanded={open}
          aria-controls="mobile-nav"
          aria-label={open ? "Close menu" : "Open menu"}
          className="rounded-chip border border-stroke p-2.5 hover:bg-elevated"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden>
            {open ? (
              <path
                d="M6 6 L18 18 M18 6 L6 18"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            ) : (
              <path
                d="M4 7 L20 7 M4 12 L20 12 M4 17 L20 17"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            )}
          </svg>
        </button>
      </div>

      {open && (
        <nav
          id="mobile-nav"
          aria-label="Main"
          className="absolute inset-x-0 top-16 border-b border-stroke bg-base p-3 sm:hidden"
        >
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded-chip px-3 py-3 text-[15px] font-semibold text-fg-secondary hover:bg-elevated hover:text-fg"
            >
              {item.label}
            </Link>
          ))}
        </nav>
      )}
    </>
  );
}
