"use client";

import { useState } from "react";
import {
  BootScreen,
  ConnectScreen,
  LanguageScreen,
  PendingApprovalScreen,
  SetupScreen,
  SignInScreen,
  WelcomeScreen,
} from "@/components/auth/AuthScreens";
import { TwoFactorSetup } from "@/components/auth/TwoFactorSetup";
import { FilesBrowser } from "@/components/files/FilesBrowser";
import { ActivityScreen, SettingsScreen, StorageScreen } from "@/components/settings/Settings";
import { GalleryScreen, TransfersScreen } from "@/components/gallery/Gallery";
import { Preview } from "@/components/preview/Preview";
import { Shell, type Section } from "@/components/Shell";
import { Button, TextField } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { useL10n } from "@/lib/l10n";
import { useSession } from "@/lib/session";
import type { NodeModel } from "@/lib/models";
import { useUploader } from "@/lib/uploads";

/**
 * One page that shows whichever screen the session stage calls for.
 *
 * The Flutter client does the same thing with a redirecting router: the stages
 * are gates, and a person cannot navigate past one until it is satisfied, so
 * putting them anywhere else would just be a second copy of the same rule.
 */
export default function Home() {
  const { stage, locale } = useSession();
  // somebody who has been here before starts at the address, not the pitch.
  // Read during initialisation, so the welcome screen never flashes first.
  const [step, setStep] = useState<"welcome" | "language" | "connect">(() =>
    typeof window !== "undefined" && localStorage.getItem("ld.locale.chosen") === "1"
      ? "connect"
      : "welcome",
  );

  if (stage === "loading") return <BootScreen />;

  // welcome, then language, then connect: the same order the app walks
  if (stage === "needsServer") {
    if (step === "welcome") return <WelcomeScreen onContinue={() => setStep("language")} />;
    if (step === "language") {
      return (
        <LanguageScreen
          onBack={() => setStep("welcome")}
          onDone={() => {
            localStorage.setItem("ld.locale.chosen", "1");
            setStep("connect");
          }}
        />
      );
    }
    return <ConnectScreen onBack={() => setStep("language")} />;
  }

  if (stage === "needsSetup") return <SetupScreen />;
  if (stage === "signedOut") return <SignInScreen />;
  if (stage === "pendingApproval") return <PendingApprovalScreen />;
  if (stage === "mustChangePassword") return <MustChangePassword />;
  if (stage === "mustEnableTotp") return <MustEnableTotp />;

  return <Drive key={locale} />;
}

/* ------------------------------------------------------------------ drive */

function Drive() {
  const t = useL10n();
  const [section, setSection] = useState<Section>("files");
  const [folder, setFolder] = useState<{ id: string; name: string }[]>([]);
  const [preview, setPreview] = useState<NodeModel | null>(null);
  const [refresh, setRefresh] = useState(0);

  const current = folder.length ? folder[folder.length - 1] : { id: "", name: t.myFiles };

  // always into the folder on screen, whichever section asked, and through the
  // same duplicate question the browser's own drop target uses
  const { pick: pickFiles, sheet: clashSheet } = useUploader(
    section === "files" ? current.id : "",
    () => setRefresh((n) => n + 1),
  );

  const titles: Record<Section, string> = {
    files: current.name,
    gallery: t.gallery,
    shared: t.sharedWithMe,
    recent: t.recent,
    starred: t.starred,
    trash: t.trash,
    storage: t.storage,
    settings: t.settings,
    search: t.search,
    transfers: t.transfersTitle,
    activity: t.activity,
  };

  const filterFor: Record<string, "none" | "starred" | "recent" | "trash" | "shared"> = {
    files: "none",
    starred: "starred",
    recent: "recent",
    trash: "trash",
    shared: "shared",
  };

  return (
    <Shell
      section={section}
      onNavigate={(s) => {
        setSection(s);
        if (s === "files") setFolder([]);
      }}
      onUpload={(files) => void pickFiles(files)}
    >
      {section === "settings" ? (
        <SettingsScreen />
      ) : section === "storage" ? (
        <StorageScreen />
      ) : section === "activity" ? (
        <ActivityScreen />
      ) : section === "gallery" ? (
        <GalleryScreen onOpen={setPreview} />
      ) : section === "transfers" ? (
        <TransfersScreen />
      ) : section in filterFor ? (
        <>
          {section === "files" && folder.length > 0 && (
            <Breadcrumb trail={folder} onGo={(i) => setFolder(folder.slice(0, i + 1))} onRoot={() => setFolder([])} />
          )}
          <FilesBrowser
            key={`${section}:${current.id}:${refresh}`}
            folderId={section === "files" ? current.id : ""}
            filter={filterFor[section]}
            title={titles[section]}
            onOpenFolder={(node) => setFolder((t) => [...t, { id: node.id, name: node.name }])}
            onPreview={setPreview}
          />
        </>
      ) : null}

      {clashSheet}
      {preview && <Preview node={preview} onClose={() => setPreview(null)} />}
    </Shell>
  );
}

function Breadcrumb({
  trail,
  onGo,
  onRoot,
}: {
  trail: { id: string; name: string }[];
  onGo: (index: number) => void;
  onRoot: () => void;
}) {
  const t = useL10n();
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 6,
        padding: "12px 20px 0",
        flexWrap: "wrap",
      }}
      className="t-body-sm"
    >
      <button onClick={onRoot} style={btn}>
        {t.myFiles}
      </button>
      {trail.map((c, i) => (
        <span key={c.id} style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
          <span style={{ color: "var(--fg-muted)" }}>/</span>
          <button onClick={() => onGo(i)} style={btn}>
            {c.name}
          </button>
        </span>
      ))}
    </div>
  );
}

const btn: React.CSSProperties = {
  background: "none",
  border: 0,
  padding: 0,
  font: "inherit",
  color: "var(--accent)",
  cursor: "pointer",
};

/* ------------------------------------------------------------------ gates */

/**
 * The temporary-password gate, ported from auth/pages/change_password_page.
 *
 * A real form rather than a notice: this is the whole client for anyone who
 * only has a browser, so sending them to another app to get in would leave
 * them with nowhere to go.
 */
function MustChangePassword() {
  const t = useL10n();
  const { refreshUser, signOut } = useSession();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const go = async () => {
    if (next !== confirm) {
      setError(t.passwordsDoNotMatch);
      return;
    }
    if (next.length < 10) {
      setError(t.passwordTooShort);
      return;
    }
    setBusy(true);
    try {
      await api.patch(Api.mePassword, { current_password: current, new_password: next });
      await refreshUser();
    } catch (e) {
      setError(e instanceof Error ? e.message : t.errorUnexpectedTitle);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 380, display: "flex", flexDirection: "column", gap: 16 }}>
        <h1 className="t-title-lg" style={{ margin: 0 }}>
          {t.mustChangePasswordTitle}
        </h1>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: 0 }}>
          {t.mustChangePasswordBody}
        </p>
        <TextField
          value={current}
          onChange={setCurrent}
          label={t.currentPassword}
          hint={t.passwordHintExisting}
          type="password"
          glyph="lock"
          dir="ltr"
        />
        <TextField
          value={next}
          onChange={setNext}
          label={t.newPassword}
          hint={t.passwordHintNew}
          type="password"
          glyph="lock"
          dir="ltr"
        />
        <TextField
          value={confirm}
          onChange={setConfirm}
          label={t.confirmPasswordLabel}
          hint={t.confirmPasswordHint}
          type="password"
          glyph="lock"
          onEnter={go}
          dir="ltr"
        />
        {error && (
          <div className="t-body-sm" style={{ color: "var(--warning)" }}>
            {error}
          </div>
        )}
        <Button label={t.actionSave} onClick={() => void go()} busy={busy} />
        <Button label={t.settingsSignOut} variant="quiet" onClick={() => void signOut()} />
      </div>
    </div>
  );
}

/**
 * The enrolment wall an admin meets when the server requires a second factor.
 *
 * It is the setup screen itself rather than a notice about one: this is the
 * whole client for anybody who only has a browser, and telling them to go and
 * use a different app would leave them with nowhere to go.
 */
function MustEnableTotp() {
  const { refreshUser } = useSession();
  return <TwoFactorSetup required onDone={() => void refreshUser()} />;
}
