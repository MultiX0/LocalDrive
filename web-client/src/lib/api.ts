"use client";

import { Api, DEFAULT_PORT } from "./endpoints";

/**
 * The HTTP client, ported from localdrive/lib/core/services/api_client.dart.
 *
 * The web client has no bundled server address: it asks for one, the same way
 * the phone and desktop apps do, and remembers it.
 */

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly field?: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

const KEY_BASE = "ld.server";
const KEY_ACCESS = "ld.access";
const KEY_REFRESH = "ld.refresh";

/**
 * Picks the scheme for an address someone typed without one.
 *
 * Self hosted almost always means an ip or a name on the local network, and no
 * certificate authority issues certificates for either, so those get http. A
 * name that looks like a public domain is the one case where a real
 * certificate is both available and expected, so that gets https.
 *
 * This has to agree with the Flutter client and with what the server actually
 * serves. Changing one without the others breaks connecting.
 */
export function schemeFor(host: string): "http" | "https" {
  const name = host.split("/")[0].split(":")[0];
  if (!name) return "http";

  const isIPv4 = /^\d{1,3}(\.\d{1,3}){3}$/.test(name);
  const isIPv6 = name.includes(":") || name.startsWith("[");
  if (isIPv4 || isIPv6) return "http";

  const lower = name.toLowerCase();
  if (
    !lower.includes(".") ||
    lower.endsWith(".local") ||
    lower.endsWith(".lan") ||
    lower.endsWith(".home") ||
    lower.endsWith(".internal")
  ) {
    return "http";
  }
  return "https";
}

/** Turns whatever somebody typed into an absolute base url. */
export function normaliseServer(input: string): string {
  const raw = input.trim();
  if (!raw) return "";

  const hadScheme = /^https?:\/\//i.test(raw);
  const withScheme = hadScheme ? raw : `${schemeFor(raw)}://${raw}`;

  let url: URL;
  try {
    url = new URL(withScheme);
  } catch {
    return "";
  }

  // a bare address means "my Local Drive server", which is on its own port
  if (!url.port && !hadScheme) url.port = String(DEFAULT_PORT);

  return `${url.protocol}//${url.host}`.replace(/\/+$/, "");
}

type Tokens = { access: string; refresh: string };

class Client {
  private base = "";
  private access = "";
  private refresh = "";
  private refreshing: Promise<boolean> | null = null;
  private onSignedOut: (() => void) | null = null;

  load() {
    if (typeof window === "undefined") return;
    this.base = localStorage.getItem(KEY_BASE) ?? "";
    this.access = localStorage.getItem(KEY_ACCESS) ?? "";
    this.refresh = localStorage.getItem(KEY_REFRESH) ?? "";
  }

  get server() {
    return this.base;
  }

  get signedIn() {
    return Boolean(this.access);
  }

  onUnauthenticated(fn: () => void) {
    this.onSignedOut = fn;
  }

  setServer(url: string) {
    this.base = url;
    if (typeof window !== "undefined") localStorage.setItem(KEY_BASE, url);
  }

  setTokens(t: Tokens | null) {
    this.access = t?.access ?? "";
    this.refresh = t?.refresh ?? "";
    if (typeof window === "undefined") return;
    if (t) {
      localStorage.setItem(KEY_ACCESS, t.access);
      localStorage.setItem(KEY_REFRESH, t.refresh);
    } else {
      localStorage.removeItem(KEY_ACCESS);
      localStorage.removeItem(KEY_REFRESH);
    }
  }

  /** An absolute url for something a browser will fetch itself, such as an
   *  image tag's src. */
  absolute(path: string): string {
    if (!path) return "";
    if (/^https?:\/\//i.test(path)) return path;
    return `${this.base}${path.startsWith("/") ? "" : "/"}${path}`;
  }

  /** A share link the server already made absolute is left alone. */
  publicLink(raw: string): string {
    if (!raw) return raw;
    if (/^https?:\/\//i.test(raw)) return raw;
    return this.absolute(raw);
  }

  /**
   * A url an <img>, <video> or <audio> can load directly.
   *
   * Those elements cannot carry an Authorization header, so the token rides in
   * the query string. The server accepts it there for exactly this reason.
   */
  media(path: string): string {
    const url = this.absolute(path);
    // Read through to storage as well. A tile can render before load() has
    // run, and a url built without the token 401s, leaves a broken image and
    // never retries, which looks exactly like the server having no thumbnail.
    const token =
      this.access || (typeof window === "undefined" ? "" : localStorage.getItem(KEY_ACCESS) ?? "");
    if (!token) return url;
    return `${url}${url.includes("?") ? "&" : "?"}access_token=${encodeURIComponent(token)}`;
  }

  /**
   * The bytes of a file, for script rather than for an element.
   *
   * Deliberately not `media()`. A url carrying the token is what an `<img>`
   * needs, but `fetch` is a cross-origin request subject to CORS, and putting
   * the credential in the query also writes it into anything that logs a url.
   * The header is both the working answer and the safer one.
   */
  async bytes(path: string, signal?: AbortSignal): Promise<Response> {
    if (!this.base) throw new ApiError(0, "no_server", "No server is set.");
    const token =
      this.access || (typeof window === "undefined" ? "" : localStorage.getItem(KEY_ACCESS) ?? "");
    const response = await fetch(this.absolute(path), {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      signal,
    });
    if (!response.ok) {
      throw new ApiError(response.status, "download_failed", `The server returned ${response.status}.`);
    }
    return response;
  }

  async request<T>(
    method: string,
    path: string,
    options: {
      body?: unknown;
      query?: Record<string, string | number | boolean | undefined | null>;
      signal?: AbortSignal;
      retry?: boolean;
    } = {},
  ): Promise<T> {
    if (!this.base) throw new ApiError(0, "no_server", "No server is set.");

    const url = new URL(this.absolute(path));
    for (const [k, v] of Object.entries(options.query ?? {})) {
      if (v === undefined || v === null || v === "") continue;
      url.searchParams.set(k, String(v));
    }

    const headers: Record<string, string> = { Accept: "application/json" };
    if (options.body !== undefined) headers["Content-Type"] = "application/json";
    if (this.access) headers.Authorization = `Bearer ${this.access}`;

    let response: Response;
    try {
      response = await fetch(url.toString(), {
        method,
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: options.signal,
      });
    } catch (cause) {
      // a browser gives no detail on a failed connection, on purpose, so this
      // says the useful thing rather than repeating "failed to fetch"
      throw new ApiError(
        0,
        "unreachable",
        "Could not reach the server. Check the address and that it is running.",
        undefined,
      );
    }

    // one silent refresh, then give up and let the session end
    if (response.status === 401 && this.refresh && options.retry !== false) {
      const ok = await this.refreshOnce();
      if (ok) return this.request<T>(method, path, { ...options, retry: false });
      this.setTokens(null);
      this.onSignedOut?.();
    }

    if (response.status === 204) return undefined as T;

    const text = await response.text();
    const parsed = text ? safeJson(text) : null;

    if (!response.ok) {
      const err = (parsed as { error?: { code?: string; message?: string; field?: string } } | null)
        ?.error;
      throw new ApiError(
        response.status,
        err?.code ?? "error",
        err?.message ?? `The server returned ${response.status}.`,
        err?.field,
      );
    }
    return parsed as T;
  }

  get<T>(path: string, query?: Record<string, string | number | boolean | undefined | null>) {
    return this.request<T>("GET", path, { query });
  }
  post<T>(path: string, body?: unknown) {
    return this.request<T>("POST", path, { body });
  }
  patch<T>(path: string, body?: unknown) {
    return this.request<T>("PATCH", path, { body });
  }
  del<T>(path: string, body?: unknown) {
    return this.request<T>("DELETE", path, { body });
  }

  /** Collapses concurrent refreshes into one, so a screen firing five
   *  requests does not rotate the refresh token five times. */
  private refreshOnce(): Promise<boolean> {
    if (this.refreshing) return this.refreshing;
    this.refreshing = (async () => {
      try {
        const res = await fetch(this.absolute(Api.refresh), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refresh_token: this.refresh }),
        });
        if (!res.ok) return false;
        const data = (await res.json()) as {
          access_token?: string;
          refresh_token?: string;
        };
        if (!data.access_token) return false;
        this.setTokens({
          access: data.access_token,
          refresh: data.refresh_token ?? this.refresh,
        });
        return true;
      } catch {
        return false;
      } finally {
        this.refreshing = null;
      }
    })();
    return this.refreshing;
  }
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export const api = new Client();
