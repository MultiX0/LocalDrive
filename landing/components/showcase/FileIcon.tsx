/*
  The file and folder icons, drawn the way the app draws them.

  These are layered panels, not glyphs on a tile: a back panel, the sheet, and
  a front panel in the file type's own colour, with the extension set into the
  front. Same construction as the logo, which is why a folder in this app reads
  as the same object as the mark.

  The six type colours are semantic. Green means spreadsheet, red means PDF.
  They are not a decorative palette and are not used as one anywhere else on
  this site.
*/

export type FileKind =
  | "folder"
  | "doc"
  | "sheet"
  | "slides"
  | "pdf"
  | "code"
  | "media"
  | "generic";

const TONE: Record<FileKind, string> = {
  folder: "var(--color-accent)",
  doc: "var(--color-file-doc)",
  sheet: "var(--color-file-sheet)",
  slides: "var(--color-file-slides)",
  pdf: "var(--color-file-pdf)",
  code: "var(--color-file-code)",
  media: "var(--color-file-media)",
  generic: "var(--color-fg-secondary)",
};

/**
 * The back panel is the front colour mixed toward the sunken surface, which
 * is exactly what `LdColors.backPanel` does in the app rather than a second
 * hand-picked colour per type.
 */
function backPanel(front: string): string {
  return `color-mix(in srgb, var(--color-sunken) 55%, ${front})`;
}

export function FileIcon({
  size = 48,
  kind = "generic",
  label,
}: {
  size?: number;
  kind?: FileKind;
  /** the extension, set into the front panel the way the app does */
  label?: string;
}) {
  const front = TONE[kind];

  return (
    <svg viewBox="0 0 64 64" width={size} height={size} fill="none" aria-hidden>
      {/* the sheet behind, offset so the stack reads as more than one layer */}
      <path
        d="M18 8 L44 8 Q47 8 47 11 L47 50 Q47 53 44 53 L18 53 Q15 53 15 50 L15 11 Q15 8 18 8 Z"
        fill={backPanel(front)}
      />
      {/* the page itself, with the corner turned */}
      <path
        d="M14 11 L36 11 L50 25 L50 53 Q50 56 47 56 L14 56 Q11 56 11 53 L11 14 Q11 11 14 11 Z"
        fill="var(--color-mark-sheet)"
      />
      <path d="M36 11 L50 25 L39 25 Q36 25 36 22 Z" fill="#b9c4d6" />
      {/* the type band, which is where the colour lives */}
      <path
        d="M11 38 L50 38 L50 53 Q50 56 47 56 L14 56 Q11 56 11 53 Z"
        fill={front}
      />
      {label && (
        <text
          x="30.5"
          y="50"
          textAnchor="middle"
          fontSize="11"
          fontWeight="700"
          letterSpacing="0.4"
          fill="#ffffff"
          fontFamily="var(--font-sans)"
        >
          {label}
        </text>
      )}
    </svg>
  );
}
