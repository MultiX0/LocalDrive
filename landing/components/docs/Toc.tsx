"use client";

import { useEffect, useState } from "react";

import type { TocEntry } from "@/lib/docs/render";

/**
 * The on-page contents, with the current section marked as you scroll.
 *
 * The observer margin pulls the trigger line up to roughly a third down the
 * viewport, so a heading counts as current once it has settled near the top
 * rather than the instant its first pixel appears at the bottom.
 */
export function Toc({ entries }: { entries: TocEntry[] }) {
  const [active, setActive] = useState<string>("");

  useEffect(() => {
    if (entries.length === 0) return;

    const observer = new IntersectionObserver(
      (records) => {
        const visible = records
          .filter((record) => record.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible[0]) setActive(visible[0].target.id);
      },
      { rootMargin: "0px 0px -70% 0px", threshold: 0 },
    );

    const headings = entries
      .map((entry) => document.getElementById(entry.id))
      .filter((element): element is HTMLElement => element !== null);

    headings.forEach((heading) => observer.observe(heading));
    return () => observer.disconnect();
  }, [entries]);

  if (entries.length === 0) return null;

  return (
    <nav aria-label="On this page" className="text-[13px]">
      <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-[0.4px] text-fg-muted">
        On this page
      </h2>
      <ul className="space-y-1.5 border-l border-stroke">
        {entries.map((entry) => (
          <li key={entry.id}>
            <a
              href={`#${entry.id}`}
              aria-current={active === entry.id ? "location" : undefined}
              className={`-ml-px block border-l-2 leading-[18px] ${
                entry.depth === 3 ? "pl-6" : "pl-3.5"
              } ${
                active === entry.id
                  ? "border-accent font-semibold text-fg"
                  : "border-transparent text-fg-secondary hover:text-fg"
              }`}
            >
              {entry.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
