/**
 * The Local Drive mark.
 *
 * The same geometry as docs/assets/mark.svg and the same four layers the
 * Flutter client animates during onboarding: a back panel with the tab, a
 * sheet rising out of the opening, the front panel, then the sync arc and its
 * node. Keeping the layer ids means the entrance can animate here too.
 */
export function Mark({
  size = 64,
  className,
  stage = "complete",
}: {
  size?: number;
  className?: string;
  /** which layers are drawn, matching the onboarding steps */
  stage?: "closed" | "connected" | "syncing" | "complete";
}) {
  const showSheet = stage !== "closed";
  const showArc = stage === "syncing" || stage === "complete";
  const showNode = stage === "complete";

  return (
    <svg
      viewBox="0 0 64 64"
      width={size}
      height={size}
      fill="none"
      className={className}
      aria-hidden="true"
      style={{ display: "block" }}
    >
      <path
        id="logo-back"
        d="M10 12 L24 12 L29 18 L54 18 Q58 18 58 22 L58 46 Q58 50 54 50 L10 50 Q6 50 6 46 L6 16 Q6 12 10 12 Z"
        fill="#2A6FD6"
      />
      {showSheet && (
        <path
          id="logo-sheet"
          d="M14 21 L50 21 Q52 21 52 23 L52 44 L12 44 L12 23 Q12 21 14 21 Z"
          fill="#DCE3EE"
        />
      )}
      <path
        id="logo-front"
        d="M10 26 L54 26 Q58 26 58 30 L58 46 Q58 50 54 50 L10 50 Q6 50 6 46 L6 30 Q6 26 10 26 Z"
        fill="#4C8DFF"
      />
      {showArc && (
        <path
          id="logo-arc"
          d="M25.5 41.5 A8 8 0 1 1 38.5 41.5"
          stroke="#FFFFFF"
          strokeWidth={3}
          strokeLinecap="round"
        />
      )}
      {showNode && <circle id="logo-node" cx="32" cy="38" r="3.2" fill="#FFFFFF" />}
    </svg>
  );
}

/** The mark beside the product name, for a header or a sign in screen. */
export function Wordmark({ size = 28 }: { size?: number }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
      <Mark size={size} />
      <span className="t-title-md" style={{ letterSpacing: "-0.01em" }}>
        Local Drive
      </span>
    </span>
  );
}
