"use client";

import { useCallback, useEffect, useState } from "react";
import QRCode from "qrcode";
import { Icon } from "@/components/Icon";
import { Button, ErrorState, Spinner, Tappable, TextField, useToast } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { useL10n } from "@/lib/l10n";
import { useSession } from "@/lib/session";

type Enrollment = {
  secret: string;
  otpauth_url: string;
  recovery_codes?: string[];
};

/**
 * Turning on two-factor, ported from auth/pages/two_factor_setup_page.
 *
 * Open the authenticator, point it at the screen, done. The key is underneath
 * for anyone whose authenticator lives on the device already showing this
 * page, where there is no second screen to point at anything.
 *
 * An admin cannot get past this when the server requires it, so it is the only
 * screen on that path: without it this client would show a wall with nothing
 * behind it.
 */
export function TwoFactorSetup({
  required,
  onDone,
  onBack,
}: {
  required: boolean;
  onDone: () => void;
  onBack?: () => void;
}) {
  const t = useL10n();
  const toast = useToast();
  const { user, signOut } = useSession();

  const [data, setData] = useState<Enrollment | null>(null);
  const [qr, setQr] = useState("");
  const [mode, setMode] = useState<"qr" | "key">("qr");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [loadError, setLoadError] = useState("");
  const [busy, setBusy] = useState(false);
  const [codes, setCodes] = useState<string[]>([]);

  const begin = useCallback(async () => {
    setLoadError("");
    try {
      const started = await api.post<Enrollment>(Api.totpBegin, {});
      setData(started);
      if (started?.otpauth_url) {
        // drawn here rather than fetched from a chart service, because the url
        // carries the secret and nobody else needs to see it
        setQr(
          await QRCode.toDataURL(started.otpauth_url, {
            width: 220,
            margin: 1,
            color: { dark: "#000000", light: "#FFFFFF" },
          }),
        );
      }
    } catch (e) {
      setLoadError(e instanceof Error ? e.message : t.errorUnexpectedTitle);
    }
  }, [t]);

  useEffect(() => {
    void begin();
  }, [begin]);

  const confirm = async () => {
    if (code.trim().length < 6) {
      setError(t.twoFactorCodeHint);
      return;
    }
    setBusy(true);
    setError("");
    try {
      await api.post(Api.totpVerify, { code: code.trim() });
      toast(t.twoFactorOn, "success");
      if (data?.recovery_codes?.length) {
        setCodes(data.recovery_codes);
        return;
      }
      onDone();
    } catch (e) {
      setError(e instanceof Error ? e.message : t.errorUnexpectedTitle);
    } finally {
      setBusy(false);
    }
  };

  // already on: there is nothing to enrol and saying so beats an empty form
  if (user?.totp_enabled && codes.length === 0) {
    return (
      <Frame title={t.twoFactorTitle} onBack={onBack}>
        <div style={{ display: "grid", placeItems: "center", padding: "40px 0", textAlign: "center" }}>
          <Icon glyph="lock" size={40} color="var(--accent)" />
          <div className="t-title-sm" style={{ margin: "14px 0 6px" }}>
            {t.twoFactorOn}
          </div>
          <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: 0 }}>
            {t.twoFactorAlreadyOnBody}
          </p>
        </div>
      </Frame>
    );
  }

  if (codes.length > 0) {
    return (
      <Frame title={t.recoveryCodesTitle}>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 16px" }}>
          {t.recoveryCodesBody}
        </p>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(130px, 1fr))",
            gap: 8,
            marginBottom: 18,
          }}
        >
          {codes.map((one) => (
            <span
              key={one}
              className="t-body-md"
              dir="ltr"
              style={{
                padding: "10px 12px",
                background: "var(--bg-sunken)",
                border: "1px solid var(--stroke)",
                borderRadius: "var(--r-chip)",
                fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
                textAlign: "center",
              }}
            >
              {one}
            </span>
          ))}
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <Button
            label={t.actionCopy}
            glyph="copy"
            variant="quiet"
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(codes.join("\n"));
                toast(t.actionCopied, "success");
              } catch {
                toast(t.errorUnexpectedTitle, "error");
              }
            }}
          />
          <Button label={t.actionDone} onClick={onDone} />
        </div>
      </Frame>
    );
  }

  if (loadError) {
    return (
      <Frame title={t.twoFactorTitle} onBack={onBack}>
        <ErrorState message={loadError} onRetry={() => void begin()} />
      </Frame>
    );
  }

  if (!data) {
    return (
      <Frame title={t.twoFactorTitle} onBack={onBack}>
        <div style={{ display: "grid", placeItems: "center", padding: 40 }}>
          <Spinner />
        </div>
      </Frame>
    );
  }

  return (
    <Frame title={t.twoFactorTitle} onBack={onBack}>
      <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 20px" }}>
        {required ? t.twoFactorRequiredBody : t.twoFactorOptionalBody}
      </p>

      <Step number={1} title={t.twoFactorScanTitle} />

      <div
        style={{
          display: "flex",
          gap: 4,
          padding: 4,
          background: "var(--bg-sunken)",
          border: "1px solid var(--stroke)",
          borderRadius: "var(--r-pill)",
          margin: "12px 0 16px",
        }}
      >
        {(["qr", "key"] as const).map((id) => {
          const active = mode === id;
          return (
            <Tappable
              key={id}
              onClick={() => setMode(id)}
              radius={999}
              style={{
                flex: 1,
                padding: "10px 0",
                textAlign: "center",
                background: active ? "var(--accent)" : "transparent",
                color: active ? "#FFFFFF" : "var(--fg-secondary)",
              }}
            >
              <span className="t-label-lg">{id === "qr" ? t.twoFactorUseQr : t.twoFactorUseKey}</span>
            </Tappable>
          );
        })}
      </div>

      {mode === "qr" ? (
        <div style={{ display: "grid", placeItems: "center", marginBottom: 20 }}>
          {qr ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={qr}
              alt={t.twoFactorUseQr}
              width={220}
              height={220}
              style={{ borderRadius: 12, background: "#FFFFFF", padding: 10 }}
            />
          ) : (
            <Spinner />
          )}
        </div>
      ) : (
        <div style={{ marginBottom: 20 }}>
          <p className="t-body-sm" style={{ color: "var(--fg-secondary)", margin: "0 0 10px" }}>
            {t.twoFactorKeyBody}
          </p>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
              padding: "12px 14px",
              background: "var(--bg-sunken)",
              border: "1px solid var(--stroke)",
              borderRadius: "var(--r-field)",
            }}
          >
            <span
              className="t-body-md"
              dir="ltr"
              style={{
                flex: 1,
                minWidth: 0,
                overflowWrap: "anywhere",
                fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
              }}
            >
              {data.secret}
            </span>
            <Tappable
              radius={8}
              style={{ padding: 6, color: "var(--accent)" }}
              title={t.actionCopyCode}
              onClick={async () => {
                try {
                  await navigator.clipboard.writeText(data.secret);
                  toast(t.actionCopied, "success");
                } catch {
                  toast(t.errorUnexpectedTitle, "error");
                }
              }}
            >
              <Icon glyph="copy" size={17} />
            </Tappable>
          </div>
        </div>
      )}

      <Step number={2} title={t.twoFactorConfirmTitle} />
      <div style={{ margin: "12px 0 16px" }}>
        <TextField
          value={code}
          onChange={setCode}
          label={t.twoFactorCode}
          hint={t.twoFactorCodeHint}
          glyph="lock"
          dir="ltr"
          onEnter={confirm}
        />
      </div>
      {error && (
        <div className="t-body-sm" style={{ color: "var(--warning)", marginBottom: 12 }}>
          {error}
        </div>
      )}
      <Button label={t.twoFactorTurnOn} glyph="lock" onClick={() => void confirm()} busy={busy} />

      {required && (
        <div style={{ marginTop: 10 }}>
          <Button label={t.settingsSignOut} variant="quiet" onClick={() => void signOut()} />
        </div>
      )}
    </Frame>
  );
}

function Frame({
  title,
  onBack,
  children,
}: {
  title: string;
  onBack?: () => void;
  children: React.ReactNode;
}) {
  const t = useL10n();
  return (
    <div style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 460 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 18 }}>
          {onBack && (
            <Tappable onClick={onBack} radius={999} style={{ padding: 8 }} title={t.actionBack}>
              <Icon glyph="chevron-left" size={20} />
            </Tappable>
          )}
          <h1 className="t-title-lg" style={{ margin: 0 }}>
            {title}
          </h1>
        </div>
        {children}
      </div>
    </div>
  );
}

function Step({ number, title }: { number: number; title: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <span
        style={{
          width: 24,
          height: 24,
          flex: "none",
          borderRadius: 999,
          background: "var(--accent)",
          color: "#FFFFFF",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          fontWeight: 700,
          fontSize: 12,
        }}
      >
        {number}
      </span>
      <span className="t-title-sm">{title}</span>
    </div>
  );
}
