/*
  The Local Drive mark.

  This is the same geometry the app draws and the same geometry in
  docs/assets/mark.svg, on a 64 by 64 box. Solid layered panels, no gradients,
  no shadows.

  The app builds the mark up one layer per onboarding step: a closed folder,
  then the contents rise, then the sync arc draws, then the node fills. Same
  sequence someone sees the first time they set the app up, reused here as
  the hero animation rather than a separate one made up for the site.

  One correction carried over from the app source: mark.svg's arc command does
  not match what the code draws. The code is authoritative, so the arc below is
  rebuilt from its values (centre 32,38, radius 8, sweeping 280.8 degrees from
  129.6) rather than copied from the SVG file.
*/

type MarkStage = "closed" | "connected" | "syncing" | "complete";

const STAGE_INDEX: Record<MarkStage, number> = {
  closed: 0,
  connected: 1,
  syncing: 2,
  complete: 3,
};

/** The arc's drawn length, for the dash offset that makes it draw itself in. */
const ARC_LENGTH = 40;

type MarkProps = {
  size?: number;
  stage?: MarkStage;
  /** cycles through all four stages, for the hero */
  animated?: boolean;
  className?: string;
  title?: string;
};

export function Mark({
  size = 64,
  stage = "complete",
  animated = false,
  className,
  title,
}: MarkProps) {
  const step = STAGE_INDEX[stage];

  // when animating, every layer is present and CSS drives it. when static,
  // only the layers that stage has reached are drawn at all
  const showSheet = animated || step >= 1;
  const showArc = animated || step >= 2;
  const showNode = animated || step >= 1;

  return (
    <svg
      viewBox="0 0 64 64"
      width={size}
      height={size}
      fill="none"
      className={className}
      role={title ? "img" : "presentation"}
      aria-label={title}
      aria-hidden={title ? undefined : true}
    >
      {/* the folder back and its tab, always visible */}
      <path
        d="M10 12 L24 12 L29 18 L54 18 Q58 18 58 22 L58 46 Q58 50 54 50 L10 50 Q6 50 6 46 L6 16 Q6 12 10 12 Z"
        fill="var(--color-mark-back)"
      />

      {/* the contents. drawn between the two panels, which makes it
          read as rising out of the folder opening rather than floating */}
      {showSheet && (
        <g clipPath="url(#ld-mark-clip)">
          <path
            d="M14 21 L50 21 Q52 21 52 23 L52 44 L12 44 L12 23 Q12 21 14 21 Z"
            fill="var(--color-mark-sheet)"
            className={animated ? "ld-mark-sheet" : undefined}
          />
        </g>
      )}

      {/* the front panel, the brightest shape */}
      <path
        d="M10 26 L54 26 Q58 26 58 30 L58 46 Q58 50 54 50 L10 50 Q6 50 6 46 L6 30 Q6 26 10 26 Z"
        fill="var(--color-accent)"
      />

      {/* the sync arc. the gap is deliberate, it is where an arrow would enter */}
      {showArc && (
        <path
          d="M26.90 44.16 A8 8 0 1 1 37.10 44.16"
          stroke="#ffffff"
          strokeWidth={3}
          strokeLinecap="round"
          className={animated ? "ld-mark-arc" : undefined}
          strokeDasharray={animated ? ARC_LENGTH : undefined}
        />
      )}

      {/* the connection dot, at the exact centre of the arc */}
      {showNode && (
        <circle
          cx={32}
          cy={38}
          r={3.2}
          fill="#ffffff"
          className={animated ? "ld-mark-node" : undefined}
        />
      )}

      <defs>
        {/* the sheet is clipped at the front panel's top edge so it appears to
            slide out from behind it rather than over it */}
        <clipPath id="ld-mark-clip">
          <rect x="0" y="0" width="64" height="50" />
        </clipPath>
      </defs>
    </svg>
  );
}

/**
 * The mark next to the product name. The name is always live text in Space
 * Grotesk, never an image, so it stays crisp and selectable.
 */
