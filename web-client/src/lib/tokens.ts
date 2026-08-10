/**
 * The design tokens again, in TypeScript.
 *
 * globals.css owns them for styling. These exist for the places that have to
 * reason about a value rather than apply it: picking a file type colour from a
 * mime type, deciding a breakpoint, timing an animation in code. Both are
 * ported from localdrive/lib/core/constants and must stay in step with it.
 */

export const LdColors = {
  backgroundPrimary: "#141414",
  backgroundElevated: "#202020",
  backgroundSunken: "#0E0E0E",

  foregroundPrimary: "#FFFFFF",
  foregroundSecondary: "#909090",
  foregroundMuted: "#434343",

  strokeOutline: "#3D3D3D",

  accentPrimary: "#4C8DFF",
  accentWarning: "#EE7759",

  fileDocument: "#4C8DFF",
  fileSpreadsheet: "#4CAF6D",
  filePresentation: "#E8935C",
  filePdf: "#E5646B",
  fileCode: "#9B7BEF",
  fileMedia: "#4CC6C6",
  fileNeutral: "#909090",
} as const;

/** A fixed row rather than an open wheel, so the browser never turns into a rainbow. */
export const folderSwatches: Record<string, string> = {
  neutral: "#6E6E6E",
  blue: LdColors.accentPrimary,
  green: LdColors.fileSpreadsheet,
  orange: LdColors.filePresentation,
  red: LdColors.filePdf,
  purple: LdColors.fileCode,
  teal: LdColors.fileMedia,
};

/** A low alpha wash of an accent, for a selected row or a badge fill. */
export function wash(hex: string, opacity = 0.14): string {
  const n = hex.replace("#", "");
  const r = parseInt(n.slice(0, 2), 16);
  const g = parseInt(n.slice(2, 4), 16);
  const b = parseInt(n.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}

/** The darker companion shade behind a layered icon's front panel. */
export function backPanel(front: string): string {
  return mix(front, LdColors.backgroundSunken, 0.55);
}

function mix(a: string, b: string, t: number): string {
  const pa = a.replace("#", "");
  const pb = b.replace("#", "");
  const out = [0, 2, 4].map((i) => {
    const ca = parseInt(pa.slice(i, i + 2), 16);
    const cb = parseInt(pb.slice(i, i + 2), 16);
    return Math.round(ca + (cb - ca) * t)
      .toString(16)
      .padStart(2, "0");
  });
  return `#${out.join("")}`;
}

export const LdRadii = {
  card: 16,
  pill: 24,
  sheet: 16,
  field: 12,
  chip: 10,
  tile: 14,
  utilityButtonSize: 42,
  minTouchTarget: 48,
  buttonHeight: 48,
} as const;

export const LdMotion = {
  standard: 280,
  tapFade: 120,
  authStep: 400,
  sheet: 320,
  toast: 240,
  toastVisible: 4000,
  hover: 200,
  spinner: 1200,
  slideOffset: 16,
} as const;

export const Breakpoints = {
  mobileMax: 600,
  tabletMax: 1024,
  gridColumnsMobile: 2,
  gridColumnsTablet: 4,
  gridColumnsDesktop: 6,
  detailPaneWidth: 380,
  contentMaxWidth: 640,
} as const;

export type DeviceClass = "mobile" | "tablet" | "desktop";

export function deviceClassFor(width: number): DeviceClass {
  if (width <= Breakpoints.mobileMax) return "mobile";
  if (width <= Breakpoints.tabletMax) return "tablet";
  return "desktop";
}

/**
 * What kind of thing a file is, which decides its colour and its glyph.
 *
 * The six tones are semantic. They say what a file is, so they must not be
 * used decoratively anywhere else.
 */
export type FileCategory =
  | "folder"
  | "image"
  | "video"
  | "audio"
  | "pdf"
  | "document"
  | "spreadsheet"
  | "presentation"
  | "code"
  | "archive"
  | "other";

export function categoryFor(mimeType: string, isFolder = false): FileCategory {
  if (isFolder) return "folder";
  const m = (mimeType || "").toLowerCase();
  if (m.startsWith("image/")) return "image";
  if (m.startsWith("video/")) return "video";
  if (m.startsWith("audio/")) return "audio";
  if (m.includes("pdf")) return "pdf";
  if (m.includes("spreadsheet") || m.includes("excel") || m.includes("csv"))
    return "spreadsheet";
  if (m.includes("presentation") || m.includes("powerpoint"))
    return "presentation";
  if (
    m.includes("json") ||
    m.includes("xml") ||
    m.includes("javascript") ||
    m.includes("typescript") ||
    m.includes("x-sh") ||
    m.includes("x-python")
  )
    return "code";
  if (
    m.includes("zip") ||
    m.includes("tar") ||
    m.includes("compress") ||
    m.includes("7z") ||
    m.includes("rar")
  )
    return "archive";
  if (m.startsWith("text/") || m.includes("word") || m.includes("document"))
    return "document";
  return "other";
}

export function colorForCategory(category: FileCategory): string {
  switch (category) {
    case "folder":
      return LdColors.accentPrimary;
    case "image":
    case "video":
    case "audio":
      return LdColors.fileMedia;
    case "pdf":
      return LdColors.filePdf;
    case "spreadsheet":
      return LdColors.fileSpreadsheet;
    case "presentation":
      return LdColors.filePresentation;
    case "code":
      return LdColors.fileCode;
    case "document":
      return LdColors.fileDocument;
    case "archive":
      return LdColors.filePresentation;
    default:
      return LdColors.fileNeutral;
  }
}
