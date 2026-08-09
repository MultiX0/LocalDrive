import { Mark } from "@/components/brand/Mark";

/*
  The window the demo screens sit in.

  The desktop app draws its own title bar rather than using the system one, so
  the frame here does the same: a sunken strip, the mark, the window name, and
  the three controls on the right. On macOS the app keeps the traffic lights
  and only replaces the bar behind them, which is why this shows the Windows
  and Linux treatment.
*/

export function DesktopFrame({
  title = "Local Drive",
  children,
  className,
}: {
  title?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`overflow-hidden rounded-card border border-stroke bg-base ${className ?? ""}`}
    >
      <div className="flex h-9 items-center gap-2.5 border-b border-stroke bg-sunken px-3">
        <Mark size={15} />
        <span className="text-[11px] text-fg-secondary">{title}</span>
        <div className="ml-auto flex items-center gap-4 pr-1" aria-hidden>
          {/* minimise, maximise, close, drawn rather than typed as glyphs */}
          <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden>
            <line
              x1="0"
              y1="5"
              x2="10"
              y2="5"
              stroke="var(--color-fg-muted)"
              strokeWidth="1.1"
            />
          </svg>
          <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden>
            <rect
              x="0.5"
              y="0.5"
              width="9"
              height="9"
              fill="none"
              stroke="var(--color-fg-muted)"
              strokeWidth="1.1"
            />
          </svg>
          <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden>
            <path
              d="M0 0 L10 10 M10 0 L0 10"
              stroke="var(--color-fg-muted)"
              strokeWidth="1.1"
            />
          </svg>
        </div>
      </div>
      {children}
    </div>
  );
}

/**
 * A phone, for the screens where the mobile layout is the point. The bezel is
 * drawn rather than photographed so it stays flat and needs no image.
 */
export function PhoneFrame({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`overflow-hidden rounded-[2rem] border-[6px] border-elevated bg-base ring-1 ring-stroke ${className ?? ""}`}
    >
      <div className="relative">
        {/* the cutout, which makes it read as a phone at a glance */}
        <div className="absolute left-1/2 top-2 z-10 h-4 w-20 -translate-x-1/2 rounded-pill bg-sunken" />
        {children}
      </div>
    </div>
  );
}
