"use client";

import { useState } from "react";

/*
  Windows and Linux side by side, one visible at a time.

  Every step on this page differs between the two in some small way, and a page
  that lists both inline doubles its own length and makes a reader check which
  half applies to them at every single step. One choice at the top, then
  everything below it is theirs.
*/

export type Platform = "windows" | "linux";

export function PlatformTabs({
  windows,
  linux,
}: {
  windows: React.ReactNode;
  linux: React.ReactNode;
}) {
  const [platform, setPlatform] = useState<Platform>("windows");

  return (
    <div>
      <div
        role="tablist"
        aria-label="Operating system"
        className="inline-flex gap-1 rounded-pill border border-stroke p-1"
      >
        <Tab
          id="windows"
          label="Windows"
          active={platform === "windows"}
          onSelect={setPlatform}
        />
        <Tab
          id="linux"
          label="Linux"
          active={platform === "linux"}
          onSelect={setPlatform}
        />
      </div>

      <div
        role="tabpanel"
        id={`panel-${platform}`}
        aria-labelledby={`tab-${platform}`}
        className="mt-7"
      >
        {platform === "windows" ? windows : linux}
      </div>
    </div>
  );
}

function Tab({
  id,
  label,
  active,
  onSelect,
}: {
  id: Platform;
  label: string;
  active: boolean;
  onSelect: (value: Platform) => void;
}) {
  return (
    <button
      type="button"
      role="tab"
      id={`tab-${id}`}
      aria-selected={active}
      aria-controls={`panel-${id}`}
      onClick={() => onSelect(id)}
      className={
        active
          ? "rounded-pill bg-accent px-5 py-2 text-[14px] font-semibold"
          : "rounded-pill px-5 py-2 text-[14px] font-semibold text-fg-secondary hover:text-fg"
      }
    >
      {label}
    </button>
  );
}

/** One numbered step, with its commands underneath. */
export function Step({
  n,
  title,
  children,
}: {
  n: number;
  title: string;
  children?: React.ReactNode;
}) {
  return (
    <li className="relative border-l border-stroke pb-8 pl-8 last:border-transparent last:pb-0">
      <span className="absolute -left-[13px] top-0 flex h-[26px] w-[26px] items-center justify-center rounded-full border border-stroke bg-elevated text-[12px] font-semibold">
        {n}
      </span>
      <h3 className="text-[16px] font-semibold leading-[24px]">{title}</h3>
      {children && <div className="mt-3">{children}</div>}
    </li>
  );
}
