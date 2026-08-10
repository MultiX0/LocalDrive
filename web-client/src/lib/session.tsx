"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api, ApiError } from "./api";
import { Api } from "./endpoints";
import type { LoginResult, UserModel } from "./models";

/**
 * Where the session is, ported from SessionStage in the Flutter client.
 *
 * The order matters: the router walks these in sequence, and each one is a
 * screen the person cannot navigate past until it is satisfied.
 */
export type SessionStage =
  | "loading"
  | "needsServer"
  | "needsSetup"
  | "signedOut"
  | "pendingApproval"
  | "mustChangePassword"
  | "mustEnableTotp"
  | "ready";

interface SessionValue {
  stage: SessionStage;
  user: UserModel | null;
  server: string;
  pendingSessionId: string;
  error: string;
  locale: "en" | "ar";

  setLocale(locale: "en" | "ar"): void;
  connect(address: string): Promise<void>;
  signIn(username: string, password: string, totp?: string): Promise<void>;
  setupFirstAdmin(v: {
    username: string;
    password: string;
    serverName: string;
  }): Promise<void>;
  signOut(): Promise<void>;
  refreshUser(): Promise<void>;
  cancelPending(): void;
  forgetServer(): void;
}

const Ctx = createContext<SessionValue | null>(null);

export function useSession() {
  const value = useContext(Ctx);
  if (!value) throw new Error("useSession used outside SessionProvider");
  return value;
}

const device = () => ({
  device_name: typeof navigator === "undefined" ? "web" : `Web on ${platformName()}`,
  platform: "web",
});

function platformName() {
  const ua = navigator.userAgent;
  if (/Windows/i.test(ua)) return "Windows";
  if (/Macintosh|Mac OS/i.test(ua)) return "macOS";
  if (/Android/i.test(ua)) return "Android";
  if (/iPhone|iPad/i.test(ua)) return "iOS";
  if (/Linux/i.test(ua)) return "Linux";
  return "the web";
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [stage, setStage] = useState<SessionStage>("loading");
  const [user, setUser] = useState<UserModel | null>(null);
  const [server, setServer] = useState("");
  const [pendingSessionId, setPendingSessionId] = useState("");
  const [error, setError] = useState("");
  const [locale, setLocaleState] = useState<"en" | "ar">(() =>
    typeof window === "undefined"
      ? "en"
      : ((localStorage.getItem("ld.locale") as "en" | "ar") ?? "en"),
  );

  const setLocale = useCallback((next: "en" | "ar") => {
    setLocaleState(next);
    localStorage.setItem("ld.locale", next);
    document.documentElement.lang = next;
    document.documentElement.dir = next === "ar" ? "rtl" : "ltr";
  }, []);

  /** Decides which screen the person belongs on, from what the server says
   *  about them. Every gate lives here rather than being scattered. */
  const settle = useCallback((u: UserModel | null) => {
    if (!u) {
      setStage("signedOut");
      return;
    }
    setUser(u);
    if (u.must_change_password) setStage("mustChangePassword");
    else if (u.must_enable_totp) setStage("mustEnableTotp");
    else setStage("ready");
  }, []);

  const refreshUser = useCallback(async () => {
    try {
      const me = await api.get<UserModel>(Api.me);
      settle(me);
    } catch {
      settle(null);
    }
  }, [settle]);

  // first run: what do we already know?
  //
  // Every set here follows either reading storage or asking the server, so it
  // cannot be hoisted into initialisation. Each path sets the stage once and
  // stops, so the cascade the linter warns about does not happen.
  useEffect(() => {
    api.load();
    // the element attributes still have to be applied once on mount, but the
    // value itself came from initialisation rather than from a second render
    document.documentElement.lang = locale;
    document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";

    api.onUnauthenticated(() => {
      setUser(null);
      setStage("signedOut");
    });

    const base = api.server;
    setServer(base);
    if (!base) {
      setStage("needsServer");
      return;
    }
    void (async () => {
      try {
        const status = await api.get<{ setup_required?: boolean }>(Api.status);
        if (status?.setup_required) {
          setStage("needsSetup");
          return;
        }
        if (!api.signedIn) {
          setStage("signedOut");
          return;
        }
        await refreshUser();
      } catch {
        // the address is remembered but nothing answers there
        setStage("needsServer");
        setError("That server did not answer. Check the address, or that it is running.");
      }
    })();
  }, [refreshUser]);

  const connect = useCallback(async (address: string) => {
    setError("");
    api.setServer(address);
    setServer(address);
    try {
      const status = await api.get<{ setup_required?: boolean; server_name?: string }>(Api.status);
      setStage(status?.setup_required ? "needsSetup" : "signedOut");
    } catch (e) {
      api.setServer("");
      setServer("");
      setStage("needsServer");
      throw e;
    }
  }, []);

  const signIn = useCallback(
    async (username: string, password: string, totp?: string) => {
      setError("");
      const result = await api.post<LoginResult>(Api.login, {
        username,
        password,
        ...(totp ? { totp_code: totp } : {}),
        ...device(),
      });

      // a held device gets a pending token rather than a session
      if (result.pending) {
        setPendingSessionId(result.session_id ?? "");
        setStage("pendingApproval");
        return;
      }
      if (!result.access_token) throw new ApiError(0, "no_token", "The server sent no session.");
      api.setTokens({ access: result.access_token, refresh: result.refresh_token ?? "" });
      await refreshUser();
    },
    [refreshUser],
  );

  const setupFirstAdmin = useCallback(
    async (v: { username: string; password: string; serverName: string }) => {
      const result = await api.post<LoginResult>(Api.setup, {
        username: v.username,
        password: v.password,
        server_name: v.serverName,
        ...device(),
      });
      if (!result.access_token) throw new ApiError(0, "no_token", "The server sent no session.");
      api.setTokens({ access: result.access_token, refresh: result.refresh_token ?? "" });
      await refreshUser();
    },
    [refreshUser],
  );

  const signOut = useCallback(async () => {
    try {
      await api.post(Api.logout, {});
    } catch {
      // signing out locally is what matters; a server that refuses is not a
      // reason to keep somebody signed in on this machine
    }
    api.setTokens(null);
    setUser(null);
    setStage("signedOut");
  }, []);

  const cancelPending = useCallback(() => {
    setPendingSessionId("");
    api.setTokens(null);
    setStage("signedOut");
  }, []);

  const forgetServer = useCallback(() => {
    api.setTokens(null);
    api.setServer("");
    setServer("");
    setUser(null);
    setStage("needsServer");
  }, []);

  const value = useMemo<SessionValue>(
    () => ({
      stage,
      user,
      server,
      pendingSessionId,
      error,
      locale,
      setLocale,
      connect,
      signIn,
      setupFirstAdmin,
      signOut,
      refreshUser,
      cancelPending,
      forgetServer,
    }),
    [
      stage,
      user,
      server,
      pendingSessionId,
      error,
      locale,
      setLocale,
      connect,
      signIn,
      setupFirstAdmin,
      signOut,
      refreshUser,
      cancelPending,
      forgetServer,
    ],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
