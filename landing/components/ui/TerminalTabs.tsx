"use client";

import { useState } from "react";

import type { Line } from "./Terminal";

// two ways to start the server, tabbed instead of stacked so it's clear
// which one to actually run

export type TerminalTab = {
  id: string;
  label: string;
  lines: Line[];
  note?: string;
};

export function TerminalTabs({ tabs }: { tabs: TerminalTab[] }) {
  const [active, setActive] = useState(tabs[0].id);
  const current = tabs.find((tab) => tab.id === active) ?? tabs[0];

  return (
    <div className="min-w-0">
      <div
        role="tablist"
        aria-label="How to start it"
        className="flex items-center gap-7 border-b border-stroke"
      >
        {tabs.map((tab) => {
          const selected = tab.id === current.id;
          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              id={`term-tab-${tab.id}`}
              aria-selected={selected}
              aria-controls={`term-panel-${tab.id}`}
              onClick={() => setActive(tab.id)}
              className={`-mb-px border-b-2 pb-3 text-[14px] font-semibold transition-colors duration-fast ${
                selected
                  ? "border-accent text-fg"
                  : "border-transparent text-fg-muted hover:text-fg-secondary"
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      <div
        role="tabpanel"
        id={`term-panel-${current.id}`}
        aria-labelledby={`term-tab-${current.id}`}
        className="min-w-0"
      >
        <pre className="overflow-x-auto py-7 text-[13.5px] leading-[2]">
          <code className="font-mono">
            {current.lines.map((line, index) => {
              if (line.kind === "blank") return <div key={index}>&nbsp;</div>;

              if (line.kind === "comment") {
                return (
                  <div key={index} className="select-none text-fg-muted">
                    # {line.text}
                  </div>
                );
              }

              if (line.kind === "output") {
                return (
                  <div key={index} className="text-fg-secondary">
                    {line.text}
                  </div>
                );
              }

              return (
                <div key={index}>
                  <span className="select-none text-accent">$ </span>
                  <span className="text-fg">{line.text}</span>
                </div>
              );
            })}
          </code>
        </pre>

        {current.note && (
          <p className="max-w-md border-t border-stroke pt-5 text-[14px] leading-[22px] text-fg-secondary">
            {current.note}
          </p>
        )}
      </div>
    </div>
  );
}
