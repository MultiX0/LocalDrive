"use client";

import { api } from "./api";
import { stringsFor } from "./l10n";

/** A transfer's error text is shown on the transfers screen, so it has to be
 *  in the reader's language. Read at throw time rather than held, because the
 *  language can change while a queue is running. */
function say(): ReturnType<typeof stringsFor> {
  const locale = (typeof window !== "undefined" ? localStorage.getItem("ld.locale") : null) === "ar" ? "ar" : "en";
  return stringsFor(locale);
}


/**
 * Uploading, over tus.
 *
 * The server speaks tus at /api/v1/uploads/ and nothing else: a plain multipart
 * POST has nowhere to go. tus is also what makes a dropped connection
 * survivable, which matters most for exactly the large files a browser is
 * worst at sending.
 *
 * Ported from the Flutter transfer controller, minus the parts that need a
 * filesystem: a browser hands over a File object rather than a path, and a
 * File survives a page reload only if the person picks it again.
 */

const CHUNK = 5 * 1024 * 1024;

export type TransferState = "queued" | "uploading" | "done" | "failed" | "paused";

export interface Transfer {
  id: string;
  name: string;
  size: number;
  sent: number;
  state: TransferState;
  error?: string;
}

type Listener = (list: Transfer[]) => void;

/** base64 of a utf-8 string, which is what tus metadata values are. */
function b64(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary);
}

class Transfers {
  private items: Transfer[] = [];
  private listeners = new Set<Listener>();
  private nextId = 1;

  subscribe(fn: Listener) {
    this.listeners.add(fn);
    fn(this.items);
    return () => this.listeners.delete(fn);
  }

  private emit() {
    const snapshot = [...this.items];
    this.listeners.forEach((fn) => fn(snapshot));
  }

  private patch(id: string, changes: Partial<Transfer>) {
    this.items = this.items.map((t) => (t.id === id ? { ...t, ...changes } : t));
    this.emit();
  }

  clearFinished() {
    this.items = this.items.filter((t) => t.state !== "done");
    this.emit();
  }

  /** Queues files and uploads them one after another, so a folder of photos
   *  does not open fifty sockets at once. */
  async enqueue(
    files: File[],
    parentId: string,
    onDone?: () => void,
    /** node id per file, for the ones replacing something already there. An
     *  upload that names the node it replaces becomes a new version of it;
     *  without this the server stores a second file beside the first. */
    replacing?: Map<File, string>,
  ) {
    const queued = files.map((file) => {
      const item: Transfer = {
        id: `t${this.nextId++}`,
        name: file.name,
        size: file.size,
        sent: 0,
        state: "queued",
      };
      this.items = [...this.items, item];
      return { item, file };
    });
    this.emit();

    for (const { item, file } of queued) {
      try {
        await this.one(item.id, file, parentId, replacing?.get(file) ?? "");
        this.patch(item.id, { state: "done", sent: file.size });
      } catch (e) {
        this.patch(item.id, {
          state: "failed",
          error: e instanceof Error ? e.message : say().transferFailed,
        });
      }
    }
    onDone?.();
  }

  private async one(id: string, file: File, parentId: string, nodeId = "") {
    this.patch(id, { state: "uploading" });
    const token = localStorage.getItem("ld.access") ?? "";
    const auth = { Authorization: `Bearer ${token}` };

    // 1. creation. the metadata keys are the ones the store reads
    const meta = [
      `filename ${b64(file.name)}`,
      `filetype ${b64(file.type || "application/octet-stream")}`,
      `parent_id ${b64(parentId ?? "")}`,
      ...(nodeId ? [`node_id ${b64(nodeId)}`] : []),
    ].join(",");

    const created = await fetch(api.absolute("/api/v1/uploads/"), {
      method: "POST",
      headers: {
        ...auth,
        "Tus-Resumable": "1.0.0",
        "Upload-Length": String(file.size),
        "Upload-Metadata": meta,
      },
    });
    if (!created.ok && created.status !== 201) {
      throw new Error(say().errorUnexpectedBody);
    }
    const location = created.headers.get("Location");
    if (!location) throw new Error(say().errorUnexpectedBody);
    const target = location.startsWith("http") ? location : api.absolute(location);

    // 2. the bytes, in chunks, so progress is real and a failure is partial
    let offset = 0;
    while (offset < file.size) {
      const end = Math.min(offset + CHUNK, file.size);
      const slice = file.slice(offset, end);
      const res = await fetch(target, {
        method: "PATCH",
        headers: {
          ...auth,
          "Tus-Resumable": "1.0.0",
          "Upload-Offset": String(offset),
          "Content-Type": "application/offset+octet-stream",
        },
        body: slice,
      });
      if (!res.ok) throw new Error(say().transferFailed);
      const next = Number(res.headers.get("Upload-Offset") ?? end);
      offset = Number.isFinite(next) && next > offset ? next : end;
      this.patch(id, { sent: offset });
    }
  }
}

export const transfers = new Transfers();
