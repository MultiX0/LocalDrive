"use client";

import { useState } from "react";
import { Mark } from "@/components/Mark";
import { Button, Spinner, TextField, Tappable, useToast } from "@/components/ui";
import { Icon } from "@/components/Icon";
import { normaliseServer } from "@/lib/api";
import { useL10n } from "@/lib/l10n";
import { HIDE_TWO_FACTOR } from "@/lib/flags";
import { useSession } from "@/lib/session";

/*
  Ported screen by screen from localdrive/lib/features/onboarding/pages and
  features/auth/pages, with the strings taken from lib/l10n/app_en.arb rather
  than written again here. Where the two disagree the Flutter client is right
  and this file is the bug.
*/

/** LdScaffold: an optional back button, actions on the trailing side, and a
 *  body centred inside contentMaxWidth. */
function Scaffold({
  children,
  onBack,
  actions,
}: {
  children: React.ReactNode;
  onBack?: () => void;
  actions?: React.ReactNode;
}) {
  const t = useL10n();
  return (
    <div style={{ minHeight: "100dvh", display: "flex", flexDirection: "column" }}>
      <header
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "max(12px, env(safe-area-inset-top)) 12px 4px",
          minHeight: 56,
        }}
      >
        {onBack ? (
          <Tappable onClick={onBack} radius={999} style={{ padding: 10 }} title={t.actionBack}>
            <Icon glyph="chevron-left" size={22} />
          </Tappable>
        ) : (
          <span style={{ width: 8 }} />
        )}
        <span style={{ flex: 1 }} />
        {actions}
      </header>
      <div
        style={{
          flex: 1,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "0 20px 32px",
        }}
      >
        <div style={{ width: "100%", maxWidth: "var(--content-max)" }}>{children}</div>
      </div>
    </div>
  );
}

/** LdLanguageToggle(compact: true): the globe and the current language. */
function LanguageToggle() {
  const { locale, setLocale } = useSession();
  return (
    <Tappable
      onClick={() => setLocale(locale === "en" ? "ar" : "en")}
      radius={999}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 8,
        padding: "8px 14px",
        border: "1px solid var(--stroke)",
      }}
    >
      <Icon glyph="globe" size={17} color="var(--fg-secondary)" />
      <span className="t-label-lg">{locale === "en" ? "English" : "العربية"}</span>
    </Tappable>
  );
}

/* --------------------------------------------------------------- welcome */

export function WelcomeScreen({ onContinue }: { onContinue: () => void }) {
  const t = useL10n();
  return (
    <Scaffold actions={<LanguageToggle />}>
      <div className="ld-enter" style={{ textAlign: "center", display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Mark size={96} />
        <h1 className="t-display" style={{ margin: "28px 0 10px" }}>
          Your files, your hardware
        </h1>
        <p className="t-body-lg" style={{ color: "var(--fg-secondary)", margin: 0, maxWidth: 460 }}>
          Local Drive keeps everything on a server you run, in a place you can point at.
        </p>
        <div style={{ width: "100%", marginTop: 32 }}>
          <Button label={t.welcomeStart} onClick={onContinue} />
        </div>
      </div>
    </Scaffold>
  );
}

/* -------------------------------------------------------------- language */

export function LanguageScreen({ onDone, onBack }: { onDone: () => void; onBack?: () => void }) {
  const t = useL10n();
  const { locale, setLocale } = useSession();
  const options: { id: "en" | "ar"; label: string }[] = [
    { id: "en", label: "English" },
    { id: "ar", label: "العربية" },
  ];

  return (
    <Scaffold onBack={onBack}>
      <div className="ld-enter" style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Mark size={72} />
        <h1 className="t-headline" style={{ margin: "26px 0 24px", textAlign: "center" }}>
          Choose a language
        </h1>
        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 12 }}>
          {options.map((o) => {
            const active = locale === o.id;
            return (
              <Tappable
                key={o.id}
                onClick={() => setLocale(o.id)}
                radius={16}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 14,
                  padding: "18px 20px",
                  width: "100%",
                  border: `1px solid ${active ? "var(--accent)" : "var(--stroke)"}`,
                  background: active ? "rgba(76,141,255,0.10)" : "var(--bg-elevated)",
                }}
              >
                <span
                  style={{
                    width: 22,
                    height: 22,
                    borderRadius: 999,
                    border: `2px solid ${active ? "var(--accent)" : "var(--fg-muted)"}`,
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  {active && <span style={{ width: 10, height: 10, borderRadius: 999, background: "var(--accent)" }} />}
                </span>
                <span className="t-title-sm" dir={o.id === "ar" ? "rtl" : "ltr"}>
                  {o.label}
                </span>
              </Tappable>
            );
          })}
        </div>
        <div style={{ width: "100%", marginTop: 28 }}>
          <Button label={t.actionContinue} onClick={onDone} />
        </div>
      </div>
    </Scaffold>
  );
}

/* --------------------------------------------------------------- connect */

/**
 * DiscoveryRadar.
 *
 * The Flutter clients find servers over mDNS and draw them on a radar. A page
 * in a browser has no mDNS and cannot get one, so the radar is drawn in its
 * resting state and says so, rather than sweeping forever for something it can
 * never find. Typing the address is the supported path here.
 */
function DiscoveryRadar() {
  return (
    <div
      style={{
        position: "relative",
        height: 200,
        display: "grid",
        placeItems: "center",
        marginBottom: 4,
      }}
    >
      {[1, 0.68, 0.36].map((scale) => (
        <span
          key={scale}
          style={{
            position: "absolute",
            width: 180 * scale,
            height: 180 * scale,
            borderRadius: 999,
            border: "1px solid var(--stroke)",
          }}
        />
      ))}
      <span
        style={{
          position: "relative",
          width: 52,
          height: 52,
          borderRadius: 999,
          background: "var(--bg-elevated)",
          border: "1px solid var(--stroke)",
          display: "grid",
          placeItems: "center",
        }}
      >
        <Icon glyph="server" size={22} color="var(--fg-secondary)" />
      </span>
      <span
        className="t-body-sm"
        style={{ position: "absolute", bottom: 4, color: "var(--fg-muted)", textAlign: "center" }}
      >
        A browser cannot search the network. Type the address below.
      </span>
    </div>
  );
}

export function ConnectScreen({ onBack }: { onBack?: () => void }) {
  const t = useL10n();
  const { connect } = useSession();
  const [address, setAddress] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const go = async () => {
    const url = normaliseServer(address);
    if (!url) {
      setError("That does not look like an address.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await connect(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : t.couldNotReachServer);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold onBack={onBack} actions={<LanguageToggle />}>
      <div className="ld-enter">
        <h1 className="t-headline" style={{ margin: 0, textAlign: "center" }}>
          Connect to a server
        </h1>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", textAlign: "center", margin: "10px 0 24px" }}>
          Pick one found on your network, or type its address.
        </p>

        <DiscoveryRadar />

        <div style={{ display: "flex", justifyContent: "center", marginBottom: 20 }}>
          <Tappable radius={10} style={{ padding: "8px 12px" }} onClick={() => undefined}>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 8, color: "var(--accent)" }}>
              <Icon glyph="refresh" size={17} />
              <span className="t-label-lg">{t.scanAgain}</span>
            </span>
          </Tappable>
        </div>

        <TextField
          value={address}
          onChange={setAddress}
          label={t.enterAddressManually}
          hint={t.addressHint}
          glyph="server"
          error={error}
          autoFocus
          onEnter={go}
          dir="ltr"
        />
        <div style={{ height: 20 }} />
        <Button label={t.connectAction} onClick={go} busy={busy} />
      </div>
    </Scaffold>
  );
}

/* --------------------------------------------------------------- sign in */

export function SignInScreen() {
  const t = useL10n();
  const { signIn, server, forgetServer } = useSession();
  const toast = useToast();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [needsTotp, setNeedsTotp] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const name = server.replace(/^https?:\/\//, "");

  const go = async () => {
    if (!username.trim() || !password) {
      setError("Type a username and a password.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await signIn(username.trim(), password, needsTotp ? totp.trim() : undefined);
    } catch (e) {
      const err = e as { code?: string; message?: string };
      if (!HIDE_TWO_FACTOR && (err.code === "totp_required" || err.code === "totp_invalid")) {
        setNeedsTotp(true);
        setError(err.code === "totp_invalid" ? t.errorUnexpectedTitle : "");
        if (err.code !== "totp_invalid") toast(t.twoFactorHint);
      } else {
        setError(err.message ?? t.errorUnexpectedTitle);
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold actions={<LanguageToggle />}>
      <div className="ld-enter" style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Mark size={72} />
        <h1 className="t-headline" style={{ margin: "26px 0 8px", textAlign: "center" }}>
          {t.signInTitle}
        </h1>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 26px", textAlign: "center" }}>
          {t.signInBody({ serverName: name })}
        </p>

        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 16 }}>
          <TextField value={username} onChange={setUsername} label={t.usernameLabel} hint={t.usernameHint} glyph="user" autoFocus onEnter={go} dir="ltr" />
          <TextField value={password} onChange={setPassword} label={t.passwordLabel} hint={t.passwordHintExisting} type="password" glyph="lock" onEnter={go} dir="ltr" />
          {!HIDE_TWO_FACTOR && needsTotp && (
            <TextField value={totp} onChange={setTotp} label={t.twoFactorCode} hint={t.twoFactorHint} glyph="lock" autoFocus onEnter={go} dir="ltr" />
          )}
          {error && (
            <div className="t-body-sm" style={{ color: "var(--warning)" }}>
              {error}
            </div>
          )}
          <Button label={t.signIn} onClick={go} busy={busy} />
          <Tappable onClick={forgetServer} radius={10} style={{ padding: 10, alignSelf: "center" }}>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 8, color: "var(--accent)" }}>
              <Icon glyph="server" size={17} />
              <span className="t-label-lg">{t.settingsSwitchNode}</span>
            </span>
          </Tappable>
        </div>
      </div>
    </Scaffold>
  );
}

/* ----------------------------------------------------------------- setup */

export function SetupScreen() {
  const t = useL10n();
  const { setupFirstAdmin } = useSession();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [serverName, setServerName] = useState("Local Drive");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const go = async () => {
    if (password !== confirm) {
      setError("Those passwords do not match.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await setupFirstAdmin({ username: username.trim(), password, serverName: serverName.trim() });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create the account.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold actions={<LanguageToggle />}>
      <div className="ld-enter" style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Mark size={64} />
        <h1 className="t-headline" style={{ margin: "24px 0 8px", textAlign: "center" }}>
          Make your account
        </h1>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 24px", textAlign: "center" }}>
          This server has nobody on it yet. The first account becomes the administrator.
        </p>
        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 16 }}>
          <TextField value={serverName} onChange={setServerName} label={t.serverNameLabel} glyph="server" dir="ltr" />
          <TextField value={username} onChange={setUsername} label={t.usernameLabel} hint={t.usernameHint} glyph="user" dir="ltr" />
          <TextField value={password} onChange={setPassword} label={t.passwordLabel} type="password" glyph="lock" dir="ltr" />
          <TextField value={confirm} onChange={setConfirm} label={t.confirmPasswordHint} type="password" glyph="lock" onEnter={go} dir="ltr" />
          {error && (
            <div className="t-body-sm" style={{ color: "var(--warning)" }}>
              {error}
            </div>
          )}
          <Button label={t.createAccount} onClick={go} busy={busy} />
        </div>
      </div>
    </Scaffold>
  );
}

/* ------------------------------------------------------- pending device  */

export function PendingApprovalScreen() {
  const t = useL10n();
  const { cancelPending } = useSession();
  return (
    <Scaffold>
      <div className="ld-enter" style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center" }}>
        <Mark size={72} stage="connected" />
        <h1 className="t-headline" style={{ margin: "26px 0 8px" }}>
          Waiting to be let in
        </h1>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 24px", maxWidth: 420 }}>
          This is a new device, so somebody already signed in has to approve it.
        </p>
        <Spinner size={28} />
        <div style={{ width: "100%", marginTop: 28 }}>
          <Button label={t.actionCancel} variant="quiet" onClick={cancelPending} />
        </div>
      </div>
    </Scaffold>
  );
}

export function BootScreen() {
  return (
    <div style={{ minHeight: "100dvh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18 }}>
      <Mark size={72} stage="syncing" />
      <Spinner />
    </div>
  );
}
