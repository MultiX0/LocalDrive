"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/*
  The verification loop, as it actually ran.

  Every stage below is a real step from one change to this repository: the web
  client's device list was rewired, the test caught that it had been pointed at
  an endpoint that does not exist, and the fix was to the application rather
  than to the test. Nothing here is illustrative.

  The interaction is a tablist. Auto-advance exists so the loop reads as a loop
  without being touched, and stops for good the moment somebody takes over,
  because a panel that keeps moving under the pointer is worse than a static
  one.
*/

type Stage = {
  id: string;
  label: string;
  caption: string;
  command: string;
  output: { text: string; tone?: "muted" | "fail" | "pass" }[];
  note: string;
};

const STAGES: Stage[] = [
  {
    id: "change",
    label: "A change lands",
    caption: "The device list in the web client is rewired.",
    command: "git diff --stat",
    output: [
      { text: " src/components/settings/Settings.tsx | 4 +-", tone: "muted" },
      { text: " src/lib/endpoints.ts                 | 5 ++-", tone: "muted" },
    ],
    note: "Unit tests pass. They always would: nothing here knows what the server actually answers.",
  },
  {
    id: "run",
    label: "The test runs",
    caption: "Against a deployment, in a real browser.",
    command:
      "testsprite test run tst_devices --target-url https://drive.example --wait",
    output: [
      { text: "queued  →  running", tone: "muted" },
      { text: "step 3/4  Open the devices section", tone: "muted" },
    ],
    note: "Not a script of selectors. The steps are sentences, so the test survives the refactor that renames the button.",
  },
  {
    id: "failed",
    label: "It fails",
    caption: "On the assertion, not on a timeout.",
    command: "",
    output: [
      { text: "failed  step 4/4", tone: "fail" },
      { text: "Verify the signed-in devices are listed", tone: "muted" },
      { text: "exit 1", tone: "fail" },
    ],
    note: "The screen showed “No other devices” and looked fine. That is exactly the failure no unit test was ever going to catch.",
  },
  {
    id: "bundle",
    label: "The bundle explains it",
    caption: "Failing step, the DOM around it, a hypothesis.",
    command: "testsprite test failure get tst_devices --failed-only",
    output: [
      { text: "GET /api/v1/devices  →  404", tone: "fail" },
      { text: "hypothesis: the client calls a route the server", tone: "muted" },
      { text: "does not serve; the empty state is a caught error", tone: "muted" },
    ],
    note: "This is the part that makes a failure worth having. No reconstructing anything from scattered logs.",
  },
  {
    id: "fix",
    label: "The application is fixed",
    caption: "The test was right. The client was wrong.",
    command: "",
    output: [
      { text: "- devices: `${prefix}/devices`", tone: "fail" },
      { text: "+ sessions: `${prefix}/sessions`", tone: "pass" },
    ],
    note: "Never the other way round. A test edited until it is green still costs time to run and no longer tells anybody anything.",
  },
  {
    id: "verified",
    label: "Verified",
    caption: "The same test, replayed.",
    command: "testsprite test rerun tst_devices --wait",
    output: [
      { text: "passed  4/4 steps", tone: "pass" },
      { text: "exit 0", tone: "pass" },
    ],
    note: "And it stays in the suite, so the next person to touch this cannot break it quietly.",
  },
];

const ADVANCE_MS = 5200;

export function VerificationLoop() {
  const [active, setActive] = useState(0);
  // Somebody who has asked for less movement gets none. Read at initialisation
  // rather than corrected in an effect: this only drives a timer and never the
  // markup, so there is nothing for the server and the client to disagree on.
  const [live, setLive] = useState(
    () =>
      typeof window === "undefined" ||
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);

  // and if the preference is turned on while the page is open, stop then too
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const onChange = () => {
      if (query.matches) setLive(false);
    };
    query.addEventListener("change", onChange);
    return () => query.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    if (!live) return;
    const timer = window.setInterval(
      () => setActive((current) => (current + 1) % STAGES.length),
      ADVANCE_MS,
    );
    return () => window.clearInterval(timer);
  }, [live]);

  const take = useCallback((index: number) => {
    setLive(false);
    setActive(index);
  }, []);

  const onKeyDown = useCallback(
    (event: React.KeyboardEvent) => {
      const last = STAGES.length - 1;
      let next: number | null = null;
      if (event.key === "ArrowDown" || event.key === "ArrowRight") next = active === last ? 0 : active + 1;
      if (event.key === "ArrowUp" || event.key === "ArrowLeft") next = active === 0 ? last : active - 1;
      if (event.key === "Home") next = 0;
      if (event.key === "End") next = last;
      if (next === null) return;
      event.preventDefault();
      take(next);
      tabs.current[next]?.focus();
    },
    [active, take],
  );

  const stage = STAGES[active];

  return (
    <div className="grid min-w-0 gap-8 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)] lg:gap-12">
      <div
        role="tablist"
        aria-label="The verification loop, stage by stage"
        aria-orientation="vertical"
        onKeyDown={onKeyDown}
        className="min-w-0"
      >
        <ol className="space-y-1.5">
          {STAGES.map((item, index) => {
            const selected = index === active;
            return (
              <li key={item.id}>
                <button
                  ref={(node) => {
                    tabs.current[index] = node;
                  }}
                  role="tab"
                  id={`loop-tab-${item.id}`}
                  aria-selected={selected}
                  aria-controls={`loop-panel-${item.id}`}
                  tabIndex={selected ? 0 : -1}
                  onClick={() => take(index)}
                  className={`flex w-full items-start gap-3 rounded-tile border px-3.5 py-3 text-left transition-colors duration-standard ease-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-base ${
                    selected
                      ? "border-accent/50 bg-accent/10"
                      : "border-transparent hover:border-stroke hover:bg-elevated"
                  }`}
                >
                  <span
                    aria-hidden
                    className={`mt-[3px] grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full border text-[10px] font-semibold tabular-nums ${
                      selected
                        ? "border-accent bg-accent text-[#0e0e0e]"
                        : "border-stroke text-fg-muted"
                    }`}
                  >
                    {index + 1}
                  </span>
                  <span className="min-w-0">
                    <span
                      className={`block text-[14px] font-semibold leading-[20px] ${
                        selected ? "text-fg" : "text-fg-secondary"
                      }`}
                    >
                      {item.label}
                    </span>
                    <span className="mt-0.5 block text-[13px] leading-[19px] text-fg-muted">
                      {item.caption}
                    </span>
                  </span>
                </button>
              </li>
            );
          })}
        </ol>
      </div>

      <div
        role="tabpanel"
        id={`loop-panel-${stage.id}`}
        aria-labelledby={`loop-tab-${stage.id}`}
        tabIndex={0}
        className="min-w-0 rounded-card border border-stroke bg-sunken focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
      >
        <div className="flex items-center gap-2 border-b border-stroke px-4 py-2.5">
          <span aria-hidden className="h-2 w-2 rounded-full bg-accent" />
          <span className="text-[11px] font-semibold uppercase tracking-[1px] text-fg-muted">
            {stage.label}
          </span>
        </div>

        <div className="min-h-[150px] overflow-x-auto px-4 py-4 font-mono text-[12.5px] leading-[21px] sm:text-[13px]">
          {stage.command ? (
            <p className="whitespace-pre text-fg">
              <span aria-hidden className="select-none text-accent">
                ${" "}
              </span>
              {stage.command}
            </p>
          ) : null}
          {stage.output.map((line, index) => (
            <p
              key={index}
              className={`whitespace-pre ${
                line.tone === "fail"
                  ? "text-warning"
                  : line.tone === "pass"
                    ? "text-fg"
                    : "text-fg-secondary"
              }`}
            >
              {line.text}
            </p>
          ))}
        </div>

        <p className="border-t border-stroke px-4 py-3.5 text-[13.5px] leading-[21px] text-fg-secondary">
          {stage.note}
        </p>
      </div>
    </div>
  );
}
