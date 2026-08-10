/**
 * The glyph set, matching LdGlyph in the Flutter client.
 *
 * One visual language throughout: a 24 unit box, outline only, 1.7 stroke,
 * round caps and joins. Material icons are deliberately not used, here or
 * there, because half a set of them beside a custom set reads as two apps.
 */

export type Glyph =
  | "home"
  | "gallery"
  | "shared"
  | "recent"
  | "star"
  | "star-filled"
  | "trash"
  | "storage"
  | "settings"
  | "search"
  | "upload"
  | "download"
  | "folder"
  | "folder-plus"
  | "file"
  | "image"
  | "video"
  | "audio"
  | "pdf"
  | "code"
  | "archive"
  | "sheet"
  | "slides"
  | "more"
  | "close"
  | "check"
  | "chevron-right"
  | "chevron-left"
  | "chevron-down"
  | "arrow-left"
  | "plus"
  | "grid"
  | "list"
  | "sort"
  | "rename"
  | "share"
  | "link"
  | "eye"
  | "eye-off"
  | "lock"
  | "user"
  | "users"
  | "device"
  | "server"
  | "globe"
  | "wifi"
  | "info"
  | "alert"
  | "refresh"
  | "logout"
  | "play"
  | "pause"
  | "transfers"
  | "activity"
  | "offline"
  | "restore"
  | "copy"
  | "move";

const paths: Record<Glyph, string> = {
  home: "M4 10.5 12 4l8 6.5V19a1 1 0 0 1-1 1h-4v-5.5h-6V20H5a1 1 0 0 1-1-1z",
  gallery: "M4 6.5h16v11H4zM8 11a1.3 1.3 0 1 0 0-2.6A1.3 1.3 0 0 0 8 11zm-3.2 6 4.7-4.7L13 16l2.6-2.1L20 17",
  shared: "M8 12a2.2 2.2 0 1 0 0-4.4A2.2 2.2 0 0 0 8 12zm8-4a2 2 0 1 0 0-4 2 2 0 0 0 0 4zm0 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM9.9 10.9 14.2 8m-4.3 5.2 4.3 2.6",
  recent: "M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zm0-12v4.2l3 1.8",
  star: "m12 4.6 2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z",
  "star-filled": "m12 4.6 2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z",
  trash: "M5 7h14M10 7V5.5A1.5 1.5 0 0 1 11.5 4h1A1.5 1.5 0 0 1 14 5.5V7m-7 0 .8 11.6A1.5 1.5 0 0 0 9.3 20h5.4a1.5 1.5 0 0 0 1.5-1.4L17 7",
  storage: "M4 7.5A1.5 1.5 0 0 1 5.5 6h13A1.5 1.5 0 0 1 20 7.5v3A1.5 1.5 0 0 1 18.5 12h-13A1.5 1.5 0 0 1 4 10.5zm0 6A1.5 1.5 0 0 1 5.5 12h13a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 16.5zM7.5 9v.01M7.5 15v.01",
  settings:
    "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm7.4-2.1a7.6 7.6 0 0 0 0-1.8l2-1.5-2-3.4-2.3 1a7.6 7.6 0 0 0-1.6-.9L15.1 3h-4l-.4 2.3a7.6 7.6 0 0 0-1.6.9l-2.3-1-2 3.4 2 1.5a7.6 7.6 0 0 0 0 1.8l-2 1.5 2 3.4 2.3-1c.5.4 1 .7 1.6.9l.4 2.3h4l.4-2.3c.6-.2 1.1-.5 1.6-.9l2.3 1 2-3.4z",
  search: "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zm5-2 4 4",
  upload: "M12 20V9m0 0 4 4m-4-4-4 4M5 4h14",
  download: "M12 4v11m0 0 4-4m-4 4-4-4M5 20h14",
  folder: "M3 7.5A1.5 1.5 0 0 1 4.5 6h4l2 2.5h7A1.5 1.5 0 0 1 19 10v7.5a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 3 17.5z",
  "folder-plus":
    "M3 7.5A1.5 1.5 0 0 1 4.5 6h4l2 2.5h7A1.5 1.5 0 0 1 19 10v7.5a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 3 17.5zM11 12v4m-2-2h4",
  file: "M6 3.5h7L18 8v12.5H6zM13 3.5V8h5",
  image: "M4 6.5h16v11H4zM8 11a1.3 1.3 0 1 0 0-2.6A1.3 1.3 0 0 0 8 11zm-3.2 6 4.7-4.7L13 16l2.6-2.1L20 17",
  video: "M4 5.5h16v13H4zm6.5 4 4.5 2.5-4.5 2.5z",
  audio: "M9 17V6l9-2v11M9 17a2.2 2.2 0 1 1-4.4 0A2.2 2.2 0 0 1 9 17zm9-2a2.2 2.2 0 1 1-4.4 0A2.2 2.2 0 0 1 18 15z",
  pdf: "M6 3.5h7L18 8v12.5H6zM13 3.5V8h5M9 13h1.5a1 1 0 0 1 0 2H9zm0 0v4",
  code: "M6 3.5h7L18 8v12.5H6zM13 3.5V8h5M9.5 12.5 8 14l1.5 1.5m5-3L16 14l-1.5 1.5",
  archive: "M4 5h16v14H4zm0 4h16M12 9v3m-1.5 0h3",
  sheet: "M6 3.5h7L18 8v12.5H6zM13 3.5V8h5M8.5 12h7m-7 3h7m-3.5-3v3",
  slides: "M6 3.5h7L18 8v12.5H6zM13 3.5V8h5M8.5 12h7v4h-7z",
  more: "M6 12h.01M12 12h.01M18 12h.01",
  close: "m6 6 12 12M18 6 6 18",
  check: "m5 12.5 4.5 4.5L19 7",
  "chevron-right": "m9.5 5 7 7-7 7",
  "chevron-left": "m14.5 5-7 7 7 7",
  "chevron-down": "m5 9.5 7 7 7-7",
  "arrow-left": "M19 12H5m0 0 6-6m-6 6 6 6",
  plus: "M12 5v14M5 12h14",
  grid: "M4 4.5h6v6H4zm10 0h6v6h-6zM4 13.5h6v6H4zm10 0h6v6h-6z",
  list: "M8 6.5h12M8 12h12M8 17.5h12M4 6.5h.01M4 12h.01M4 17.5h.01",
  sort: "M6 5v14m0 0-3-3m3 3 3-3M18 19V5m0 0-3 3m3-3 3 3",
  rename: "M4 20h16M5.5 16.5 16 6a2.1 2.1 0 0 1 3 3L8.5 19.5 4 20z",
  share: "M8 12a2.2 2.2 0 1 0 0-4.4A2.2 2.2 0 0 0 8 12zm8-4a2 2 0 1 0 0-4 2 2 0 0 0 0 4zm0 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM9.9 10.9 14.2 8m-4.3 5.2 4.3 2.6",
  link: "M10 13.5a3.5 3.5 0 0 0 5 0l3-3a3.5 3.5 0 0 0-5-5l-1 1m-2 6a3.5 3.5 0 0 1-5 0l-3-3a3.5 3.5 0 0 1 5-5l1 1",
  eye: "M2.5 12S6 6 12 6s9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6zm9.5 2.6a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2z",
  "eye-off": "M4 4 20 20M9.9 5.2A7.9 7.9 0 0 1 12 5c6 0 9.5 6 9.5 6a15 15 0 0 1-3.1 3.7M6.6 7.6A15 15 0 0 0 2.5 11s3.5 6 9.5 6a8 8 0 0 0 3.3-.7",
  lock: "M6 10.5h12V20H6zM8.5 10.5V7.8a3.5 3.5 0 0 1 7 0v2.7",
  user: "M12 12a3.6 3.6 0 1 0 0-7.2A3.6 3.6 0 0 0 12 12zm-7 8a7 7 0 0 1 14 0",
  users: "M9 11.5a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4zM2.5 19.5a6.5 6.5 0 0 1 13 0M16 6.2a3 3 0 0 1 0 5.6m1 2.4a5.6 5.6 0 0 1 4.5 5.3",
  device: "M6 4h12v16H6zm4 13.5h4",
  server: "M4 5.5h16v5H4zm0 8h16v5H4zM7.5 8v.01M7.5 16v.01",
  globe: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zm-9-9h18M12 3a13 13 0 0 1 0 18 13 13 0 0 1 0-18z",
  info: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zm0-9v5m0-8.5v.01",
  alert: "M12 8v5m0 3v.01M10.3 4.2 2.7 17.4A1.9 1.9 0 0 0 4.4 20h15.2a1.9 1.9 0 0 0 1.7-2.6L13.7 4.2a1.9 1.9 0 0 0-3.4 0z",
  refresh: "M20 12a8 8 0 1 1-2.6-5.9M20 4v4h-4",
  logout: "M15 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h7a2 2 0 0 0 2-2v-2m3-4H9m11 0-3-3m3 3-3 3",
  play: "M8 5.5 19 12 8 18.5z",
  pause: "M9 5.5v13M15 5.5v13",
  transfers: "M4 8h12m0 0-3-3m3 3-3 3M20 16H8m0 0 3-3m-3 3 3 3",
  activity: "M3 12h4l3 7 4-14 3 7h4",
  offline: "M12 20V9m0 0 4 4m-4-4-4 4M6 8a6 6 0 1 1 11 3.2",
  // three arcs about a dot, the same construction the app paints
  wifi: "M7.96 16.01A4.5 4.5 0 0 1 15.19 14.83M4.38 14.24A8.5 8.5 0 0 1 18.02 12M0.79 12.47A12.5 12.5 0 0 1 20.86 9.18M12 18h.01",
  restore: "M4 12a8 8 0 1 0 2.6-5.9M4 4v4h4",
  copy: "M9 9h10v11H9zM5 15V4h10",
  move: "M12 4v16m0-16-3 3m3-3 3 3m-3 13-3-3m3 3 3-3M4 12h16m-16 0 3-3m-3 3 3 3m13-3-3-3m3 3-3 3",
};

const filled: Partial<Record<Glyph, boolean>> = { "star-filled": true, play: true, slides: false };

export function Icon({
  glyph,
  size = 20,
  color = "currentColor",
  className,
  strokeWidth = 1.7,
}: {
  glyph: Glyph;
  size?: number;
  color?: string;
  className?: string;
  strokeWidth?: number;
}) {
  const isFilled = filled[glyph];
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      aria-hidden="true"
      style={{ flex: "none", display: "block" }}
      fill={isFilled ? color : "none"}
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={paths[glyph]} />
    </svg>
  );
}
