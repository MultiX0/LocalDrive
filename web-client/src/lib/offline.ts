"use client";

import { useEffect, useState } from "react";
import { api } from "./api";
import { Api } from "./endpoints";

/**
 * Keeping a file on this device, ported from features/offline.
 *
 * The apps write to a real filesystem. A page has no filesystem, so this uses
 * the Cache Storage a browser gives it: the bytes survive a reload and a
 * closed tab, and they are readable with the server unreachable, which is the
 * property that matters.
 *
 * What it is not: this is a per device choice, the same as in the apps, not a
 * mirror of the drive. Nothing is kept without being asked for, and the
 * browser may still evict it under storage pressure, so it is a convenience
 * rather than a backup. Anything that must survive belongs on the server.
 */

const CACHE = "localdrive-offline-v1";
const INDEX = "ld.offline.index";
const CAP = "ld.offline.cap";

/** The choices the warning threshold offers. Round numbers, because nobody
 *  wants to type a byte count. 0 means no limit. */
export const capChoices = [
  512 * 1024 * 1024,
  1024 * 1024 * 1024,
  2 * 1024 * 1024 * 1024,
  5 * 1024 * 1024 * 1024,
  10 * 1024 * 1024 * 1024,
  0,
];

export type KeptEntry = { id: string; name: string; bytes: number };

export type OfflineUsage = {
  totalBytes: number;
  fileCount: number;
  softCapBytes: number;
  capFraction: number;
  overCap: boolean;
  items: KeptEntry[];
};

function supported(): boolean {
  return typeof window !== "undefined" && "caches" in window;
}

/** What is kept, with the name and size recorded at the time it was kept, so
 *  the settings screen can total it up without opening every blob. */
export function kept(): KeptEntry[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = JSON.parse(localStorage.getItem(INDEX) ?? "[]") as unknown[];
    // an earlier build stored bare ids; read those rather than dropping
    // someone's downloads on upgrade
    return raw.map((e) =>
      typeof e === "string" ? { id: e, name: "", bytes: 0 } : (e as KeptEntry),
    );
  } catch {
    return [];
  }
}

/** Which node ids are kept, so a tile can show its badge without asking the
 *  cache about every file on screen. */
export function keptIds(): Set<string> {
  return new Set(kept().map((e) => e.id));
}

function remember(entries: KeptEntry[]) {
  localStorage.setItem(INDEX, JSON.stringify(entries));
  window.dispatchEvent(new Event("ld-offline-changed"));
}

export function isKept(nodeId: string): boolean {
  return kept().some((e) => e.id === nodeId);
}

/** Downloads the file and keeps it. Returns false when the browser has no
 *  cache storage, which is the private-window case. */
export async function keep(nodeId: string, name = ""): Promise<boolean> {
  if (!supported()) return false;
  const cache = await caches.open(CACHE);
  const res = await api.bytes(Api.download(nodeId));
  // measured from the copy actually stored rather than trusting the listing,
  // so the settings total matches what is really on the device
  const body = await res.blob();
  await cache.put(keyFor(nodeId), new Response(body, { headers: res.headers }));
  remember([...kept().filter((e) => e.id !== nodeId), { id: nodeId, name, bytes: body.size }]);
  return true;
}

export async function forget(nodeId: string): Promise<void> {
  if (!supported()) return;
  const cache = await caches.open(CACHE);
  await cache.delete(keyFor(nodeId));
  remember(kept().filter((e) => e.id !== nodeId));
}

/** The kept copy, or null. Used before going to the network, so a file that is
 *  kept opens with the server switched off. */
export async function readKept(nodeId: string): Promise<Blob | null> {
  if (!supported() || !isKept(nodeId)) return null;
  const cache = await caches.open(CACHE);
  const hit = await cache.match(keyFor(nodeId));
  return hit ? await hit.blob() : null;
}

/** The soft cap is a warning, not a wall: passing it colours the number and
 *  says so, and never refuses a download. Deciding what to delete is the
 *  owner's call, not this app's. */
export function softCap(): number {
  if (typeof window === "undefined") return 0;
  const raw = Number(localStorage.getItem(CAP));
  return Number.isFinite(raw) && raw > 0 ? raw : 0;
}

export function setSoftCap(bytes: number): void {
  localStorage.setItem(CAP, String(bytes));
  window.dispatchEvent(new Event("ld-offline-changed"));
}

/** What all of this is costing on this device. */
export async function usage(): Promise<OfflineUsage> {
  const items = kept();
  let total = 0;
  if (supported()) {
    const cache = await caches.open(CACHE);
    for (const entry of items) {
      const hit = await cache.match(keyFor(entry.id));
      if (!hit) continue;
      entry.bytes = (await hit.clone().blob()).size;
      total += entry.bytes;
    }
  }
  const cap = softCap();
  return {
    totalBytes: total,
    fileCount: items.length,
    softCapBytes: cap,
    capFraction: cap > 0 ? Math.min(total / cap, 1) : 0,
    overCap: cap > 0 && total > cap,
    items,
  };
}

export async function forgetAll(): Promise<void> {
  if (!supported()) return;
  await caches.delete(CACHE);
  remember([]);
}

/** The kept set, kept current. Read from an effect rather than during render,
 *  because localStorage does not exist while the page is being rendered on the
 *  server and a badge that only appears after hydration is the right trade. */
export function useKeptIds(): Set<string> {
  const [ids, setIds] = useState<Set<string>>(new Set());
  useEffect(() => {
    const sync = () => setIds(keptIds());
    sync();
    window.addEventListener("ld-offline-changed", sync);
    return () => window.removeEventListener("ld-offline-changed", sync);
  }, []);
  return ids;
}

// a stable, same-origin key. Cache Storage wants a Request, and the real url
// carries a token that rotates.
function keyFor(nodeId: string): Request {
  return new Request(`/__offline__/${encodeURIComponent(nodeId)}`);
}
