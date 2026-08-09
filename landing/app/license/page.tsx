import fs from "node:fs/promises";
import path from "node:path";

import type { Metadata } from "next";

import { PageHeader } from "@/components/ui/PageHeader";
import { GITHUB_URL, hasRepo, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "License",
  description: `${site.name} is released under the MIT License.`,
};

/**
 * The licence, read from the repository's own LICENSE file.
 *
 * Read from the file rather than retyped into a component, so it can't
 * quietly drift from the licence that actually ships.
 */
export default async function LicensePage() {
  const text = await fs.readFile(
    path.join(process.cwd(), "..", "LICENSE"),
    "utf8",
  );

  return (
    <div className="mx-auto max-w-3xl px-5 py-14 sm:px-7 lg:px-8 lg:py-20">
      <PageHeader
        eyebrow="MIT"
        title="License"
        lead={`${site.name} is free software under the MIT License. You can run it, change it, and ship it, including commercially.`}
      />

      <dl className="border-t border-stroke">
        <Fact title="You can" body="Use, copy, modify, merge, publish, distribute, sublicense and sell." />
        <Fact title="You must" body="Keep the copyright notice and this licence text with any copy." />
        <Fact title="You get" body="No warranty. The software is provided as is." />
      </dl>

      <pre className="mt-10 overflow-x-auto border-y border-stroke bg-sunken p-6 text-[13px] leading-[1.7] whitespace-pre-wrap text-fg-secondary">
        {text.trim()}
      </pre>

      {hasRepo && (
        <p className="mt-6 text-[13px] text-fg-secondary">
          The authoritative copy lives in{" "}
          <a
            href={`${GITHUB_URL}/blob/main/LICENSE`}
            target="_blank"
            rel="noreferrer noopener"
            className="text-accent hover:underline"
          >
            the repository
          </a>
          .
        </p>
      )}
    </div>
  );
}

/*
  A plain-language summary above the legal text. It is a summary and nothing
  more: the file below it is what actually governs, which is why it is printed
  in full rather than replaced by these three lines.
*/
function Fact({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex flex-col gap-1.5 border-b border-stroke py-5 sm:flex-row sm:gap-8">
      <dt className="shrink-0 text-[15px] font-bold text-fg sm:w-28">
        {title}
      </dt>
      <dd className="text-[15px] leading-[24px] text-fg-secondary">{body}</dd>
    </div>
  );
}
