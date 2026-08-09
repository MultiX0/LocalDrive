"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

type SidebarItem = { slug: string; title: string; href: string };
export type SidebarSection = { key: string; label: string; items: SidebarItem[] };

/**
 * The documentation navigation.
 *
 * A client component only because it needs to know which page is open. On a
 * phone it collapses into a single disclosure above the content, because a
 * fixed rail would eat half the screen on the device where reading room
 * matters most.
 */
export function Sidebar({ sections }: { sections: SidebarSection[] }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  const current =
    sections
      .flatMap((section) => section.items)
      .find((item) => item.href === pathname)?.title ?? "Documentation";

  return (
    <>
      {/* phone: one disclosure naming the page you are on */}
      <div className="lg:hidden">
        <button
          type="button"
          onClick={() => setOpen((value) => !value)}
          aria-expanded={open}
          className="flex w-full items-center justify-between rounded-field border border-stroke bg-elevated px-4 py-3 text-[14px] font-semibold"
        >
          {current}
          <svg
            viewBox="0 0 24 24"
            width={18}
            height={18}
            fill="none"
            stroke="currentColor"
            strokeWidth={1.7}
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden
            className={`transition-transform ${open ? "rotate-180" : ""}`}
          >
            <path d="M5.5 9.5 L12 16 L18.5 9.5" />
          </svg>
        </button>
      </div>

      <nav
        aria-label="Documentation"
        className={`${open ? "block" : "hidden"} mt-3 lg:mt-0 lg:block`}
      >
        {sections.map((section) => (
          <div key={section.key} className="mb-7">
            {section.label && (
              <h2 className="mb-2.5 text-[11px] font-semibold uppercase tracking-[0.4px] text-fg-muted">
                {section.label}
              </h2>
            )}
            <ul className="space-y-0.5">
              {section.items.map((item) => {
                const active = pathname === item.href;
                return (
                  <li key={item.slug}>
                    <Link
                      href={item.href}
                      onClick={() => setOpen(false)}
                      aria-current={active ? "page" : undefined}
                      className={
                        active
                          ? "block rounded-chip border-l-2 border-accent bg-elevated py-1.5 pl-3 pr-3 text-[14px] font-semibold text-fg"
                          : "block rounded-chip border-l-2 border-transparent py-1.5 pl-3 pr-3 text-[14px] text-fg-secondary hover:bg-elevated hover:text-fg"
                      }
                    >
                      {item.title}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
    </>
  );
}
