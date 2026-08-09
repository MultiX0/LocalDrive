import type { Metadata } from "next";
import Link from "next/link";

import { PageHeader } from "@/components/ui/PageHeader";
import { guides } from "@/lib/guides";

export const metadata: Metadata = {
  title: "Guides",
  description:
    "Step by step answers to common questions, with a screenshot of every step.",
};

export default function GuidesPage() {
  return (
    <div className="mx-auto max-w-4xl px-5 py-14 sm:px-7 lg:px-8 lg:py-20">
      <PageHeader
        eyebrow="Guides"
        title="How do I do this?"
        lead="Common questions, answered with a screenshot of every step."
      />

      <ul className="border-t border-stroke">
        {guides.map((guide) => (
          <li key={guide.slug}>
            <Link
              href={`/guides/${guide.slug}`}
              className="group flex items-baseline gap-6 border-b border-stroke py-7 transition-colors duration-fast hover:border-fg-muted focus-visible:outline-none sm:gap-10"
            >
              <span className="hidden w-16 shrink-0 text-[12px] font-semibold uppercase tracking-[0.8px] text-fg-muted sm:block">
                {guide.minutes} min
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-[19px] font-semibold leading-[26px] text-fg transition-colors duration-fast group-hover:text-accent sm:text-[22px] sm:leading-[30px]">
                  {guide.question}
                </span>
                <span className="mt-1.5 block text-[15px] leading-[23px] text-fg-secondary">
                  {guide.summary}
                </span>
              </span>
              <span
                aria-hidden
                className="shrink-0 text-[18px] text-fg-muted transition-all duration-fast group-hover:translate-x-1 group-hover:text-accent"
              >
                &rarr;
              </span>
            </Link>
          </li>
        ))}
      </ul>

      <p className="mt-12 text-[15px] leading-[24px] text-fg-secondary">
        Looking for something more detailed?{" "}
        <Link href="/docs" className="text-accent hover:underline">
          Read the documentation
        </Link>
        .
      </p>
    </div>
  );
}
