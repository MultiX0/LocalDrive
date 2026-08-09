import type { FileKind } from "./FileIcon";

/*
  The contents of the demo.

  Ordinary things a person would actually keep on a family file server, so the
  screenshots read as somebody's drive rather than as a product mock full of
  "Document 1" and "Folder A". Every size and date is fixed, never derived from
  the current time, so the page looks identical whenever it is loaded.
*/

export type DemoTransfer = {
  name: string;
  ext: string;
  kind: FileKind;
  state: "uploading" | "queued" | "done" | "failed";
  progress: number;
  detail: string;
};

/**
 * One of each state, because the point of the transfers screen is that a
 * failure names its actual reason instead of going quiet.
 */
export const TRANSFERS: DemoTransfer[] = [
  {
    name: "Roof survey.jpg",
    ext: "JPG",
    kind: "media",
    state: "uploading",
    progress: 0.62,
    detail: "4.1 MB of 6.6 MB, 12 seconds left",
  },
  {
    name: "Kitchen rebuild.docx",
    ext: "DOCX",
    kind: "doc",
    state: "queued",
    progress: 0,
    detail: "Waiting for the upload above",
  },
  {
    name: "Site photos.zip",
    ext: "ZIP",
    kind: "generic",
    state: "failed",
    progress: 0.34,
    detail: "The server ran out of space. Free some and retry.",
  },
  {
    name: "Household budget.xlsx",
    ext: "XLSX",
    kind: "sheet",
    state: "done",
    progress: 1,
    detail: "Uploaded 2 minutes ago",
  },
];

export const PEOPLE = [
  { name: "Sara", seed: "a", nearby: true, role: "Can edit" },
  { name: "Omar", seed: "b", nearby: true, role: "Can view" },
  { name: "Layla", seed: "c", nearby: false, role: "" },
  { name: "Yusuf", seed: "d", nearby: false, role: "" },
] as const;

/**
 * Avatar colours drawn from the folder swatches, picked by seed the way the
 * app derives one from an account rather than storing a colour per person.
 */
export const AVATAR_TONES: Record<string, string> = {
  a: "var(--color-file-media)",
  b: "var(--color-file-slides)",
  c: "var(--color-file-code)",
  d: "var(--color-file-sheet)",
};
