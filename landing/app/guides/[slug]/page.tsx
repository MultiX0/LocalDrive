import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { guideBySlug, guides } from "@/lib/guides";

type Params = { params: Promise<{ slug: string }> };

export function generateStaticParams() {
  return guides.map((guide) => ({ slug: guide.slug }));
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  const guide = guideBySlug(slug);
  if (!guide) return {};
  return { title: guide.question, description: guide.summary };
}

export default async function GuidePage({ params }: Params) {
  const { slug } = await params;
  const guide = guideBySlug(slug);
  if (!guide) notFound();

  const others = guides.filter((g) => g.slug !== guide.slug).slice(0, 2);

  return (
    <div className="mx-auto max-w-3xl px-5 py-14 sm:px-7 lg:px-8 lg:py-20">
      <Link
        href="/guides"
        className="group inline-flex items-center gap-2 text-[14px] font-semibold text-fg-secondary transition-colors duration-fast hover:text-fg"
      >
        <span
          aria-hidden
          className="transition-transform duration-fast group-hover:-translate-x-1"
        >
          &larr;
        </span>
        All guides
      </Link>

      <h1 className="mt-7 text-[36px] font-bold leading-[1.1] tracking-[-0.025em] sm:text-[44px]">
        {guide.question}
      </h1>
      <p className="mt-5 text-[18px] leading-[28px] text-fg-secondary">
        {guide.summary}
      </p>
      <p className="mt-7 border-t border-stroke pt-5 text-[12px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
        {guide.steps.length} steps &middot; about {guide.minutes} min
      </p>

      <ol className="mt-14 space-y-16">
        {guide.steps.map((step, index) => (
          <li key={step.image}>
            <div className="flex items-baseline gap-4">
              <span
                aria-hidden
                className="text-[15px] font-bold tabular-nums text-accent"
              >
                {String(index + 1).padStart(2, "0")}
              </span>
              <h2 className="text-[24px] font-semibold leading-[32px] tracking-[-0.2px] text-fg">
                {step.title}
              </h2>
            </div>
            <p className="mt-3 pl-[calc(1ch+1rem)] text-[16px] leading-[26px] text-fg-secondary">
              {step.body}
            </p>
            <div className="mt-6 overflow-hidden rounded-card border border-stroke bg-sunken">
              {/* the real screen, at the size it is actually used */}
              <Image
                src={step.image}
                alt={step.alt}
                width={2880}
                height={1800}
                className="h-auto w-full"
                sizes="(min-width: 768px) 720px, 100vw"
                priority={index === 0}
              />
            </div>
          </li>
        ))}
      </ol>

      {others.length > 0 && (
        <div className="mt-20 border-t border-stroke pt-10">
          <h2 className="text-[13px] font-semibold uppercase tracking-[0.8px] text-fg-muted">
            Next
          </h2>
          <ul className="mt-4 space-y-3">
            {others.map((other) => (
              <li key={other.slug}>
                <Link
                  href={`/guides/${other.slug}`}
                  className="text-[17px] font-semibold text-fg transition-colors duration-fast hover:text-accent"
                >
                  {other.question}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
