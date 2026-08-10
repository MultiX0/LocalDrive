"use client";

import { useCallback, useEffect, useState } from "react";
import { Icon, type Glyph } from "@/components/Icon";
import {
  Avatar,
  Button,
  EmptyState,
  ListSkeleton,
  Sheet,
  Tappable,
  TextField,
  useToast,
} from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { bytes, dateTime, percent, relative } from "@/lib/format";
import type { DeviceModel, LibraryModel, UserModel } from "@/lib/models";
import { useL10n, type Strings } from "@/lib/l10n";
import { HIDE_TWO_FACTOR } from "@/lib/flags";
import { capChoices, forget, forgetAll, setSoftCap, usage, type OfflineUsage } from "@/lib/offline";
import { useSession } from "@/lib/session";
import { TwoFactorSetup } from "@/components/auth/TwoFactorSetup";

/*
  Settings, ported from features/settings. One list of sections, each opening
  its own page, in the order the app lists them. That order is declared once
  below rather than repeated here, because a comment listing it is a second
  copy that goes wrong the first time a section moves.
*/

type SectionId =
  | "root"
  | "account"
  | "devices"
  | "language"
  | "two-factor"
  | "downloads"
  | "users"
  | "server"
  | "about";

/** Declared once, in the app's order. Users and server are admin only. */
const sections: { id: SectionId; key: keyof Strings; glyph: Glyph; adminOnly?: boolean }[] = [
  { id: "account", key: "settingsAccount", glyph: "user" },
  { id: "devices", key: "devices", glyph: "device" },
  { id: "language", key: "settingsLanguage", glyph: "globe" },
  { id: "two-factor", key: "settingsTwoFactor", glyph: "lock" },
  { id: "downloads", key: "offlineDownloadsTitle", glyph: "offline" },
  { id: "users", key: "settingsUsers", glyph: "users", adminOnly: true },
  { id: "server", key: "settingsServer", glyph: "server", adminOnly: true },
  { id: "about", key: "settingsAbout", glyph: "info" },
];

export function SettingsScreen() {
  const t = useL10n();
  const { user, signOut } = useSession();
  const [section, setSection] = useState<SectionId>("root");
  const isAdmin = user?.role === "admin";

  if (section !== "root") {
    return <Detail section={section} onBack={() => setSection("root")} />;
  }

  return (
    <Page title={t.settings}>
      {user && (
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 14,
            padding: 18,
            background: "var(--bg-elevated)",
            border: "1px solid var(--stroke)",
            borderRadius: "var(--r-card)",
            marginBottom: 20,
          }}
        >
          <Avatar name={user.display_name || user.username} />
          <div style={{ minWidth: 0, flex: 1 }}>
            <div className="t-title-sm" style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
              {user.display_name || user.username}
            </div>
            <div className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
              {user.email || user.username} · {user.role === "admin" ? t.roleAdmin : t.roleMember}
            </div>
          </div>
        </div>
      )}

      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {sections
          .filter((s) => !s.adminOnly || isAdmin)
          .filter((s) => s.id !== "two-factor" || !HIDE_TWO_FACTOR)
          .map((s) => (
            <Row
              key={s.id}
              glyph={s.glyph}
              label={t[s.key] as string}
              onClick={() => setSection(s.id)}
            />
          ))}
      </div>

      <div style={{ marginTop: 24 }}>
        <Button label={t.settingsSignOut} variant="danger" glyph="logout" onClick={() => void signOut()} />
      </div>
    </Page>
  );
}

/* ------------------------------------------------------------------ parts */

function Page({ title, onBack, children }: { title: string; onBack?: () => void; children: React.ReactNode }) {
  const t = useL10n();
  return (
    <div style={{ minHeight: "100dvh" }}>
      {/* the heading sits in the same column as the content, so the two are
          not on different left edges */}
      <header
        style={{
          position: "sticky",
          top: 0,
          background: "var(--bg-primary)",
          zIndex: 60,
          padding: "max(8px, env(safe-area-inset-top)) 16px 8px",
        }}
      >
        <div
          style={{
            maxWidth: 760,
            margin: "0 auto",
            display: "flex",
            alignItems: "center",
            gap: 8,
          }}
        >
          {onBack && (
            <Tappable onClick={onBack} radius={999} style={{ padding: 8 }} title={t.actionBack}>
              <Icon glyph="chevron-left" size={20} />
            </Tappable>
          )}
          <h1 className="t-title-lg" style={{ margin: 0 }}>
            {title}
          </h1>
        </div>
      </header>
      <div style={{ padding: "8px 16px 120px", maxWidth: 760, margin: "0 auto" }}>{children}</div>
    </div>
  );
}

function Row({
  glyph,
  label,
  value,
  onClick,
  danger,
}: {
  glyph: Glyph;
  label: string;
  value?: string;
  onClick?: () => void;
  danger?: boolean;
}) {
  return (
    <Tappable
      onClick={onClick}
      radius={14}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 14,
        width: "100%",
        padding: "14px 16px",
        background: "var(--bg-elevated)",
        border: "1px solid var(--stroke)",
        color: danger ? "var(--warning)" : "var(--fg-primary)",
      }}
    >
      <Icon glyph={glyph} size={19} color={danger ? "var(--warning)" : "var(--fg-secondary)"} />
      <span className="t-body-lg" style={{ flex: 1 }}>
        {label}
      </span>
      {value && (
        <span className="t-body-md" style={{ color: "var(--fg-secondary)" }}>
          {value}
        </span>
      )}
      {onClick && <Icon glyph="chevron-right" size={17} color="var(--fg-muted)" />}
    </Tappable>
  );
}

/** A setting that is on or off, with the sentence explaining what it costs. */
function SwitchRow({
  glyph,
  label,
  description,
  value,
  onChange,
}: {
  glyph: Glyph;
  label: string;
  description: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <Tappable
      onClick={() => onChange(!value)}
      radius={14}
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: 14,
        width: "100%",
        padding: "14px 16px",
        background: "var(--bg-elevated)",
        border: "1px solid var(--stroke)",
        textAlign: "start",
      }}
    >
      <Icon glyph={glyph} size={19} color="var(--fg-secondary)" />
      <span style={{ flex: 1, minWidth: 0 }}>
        <span className="t-body-lg" style={{ display: "block" }}>
          {label}
        </span>
        <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
          {description}
        </span>
      </span>
      <span
        style={{
          width: 44,
          height: 26,
          flex: "none",
          borderRadius: 999,
          background: value ? "var(--accent)" : "var(--bg-sunken)",
          border: `1px solid ${value ? "var(--accent)" : "var(--stroke)"}`,
          display: "inline-flex",
          alignItems: "center",
          padding: 2,
          transition: "background var(--d-hover) var(--ease)",
        }}
      >
        <span
          style={{
            width: 20,
            height: 20,
            borderRadius: 999,
            background: value ? "#FFFFFF" : "var(--fg-muted)",
            marginInlineStart: value ? 18 : 0,
            transition: "margin var(--d-hover) var(--ease)",
          }}
        />
      </span>
    </Tappable>
  );
}

/* ---------------------------------------------------------------- details */

function Detail({ section, onBack }: { section: SectionId; onBack: () => void }) {
  switch (section) {
    case "account":
      return <AccountSection onBack={onBack} />;
    case "devices":
      return <DevicesSection onBack={onBack} />;
    case "users":
      return <UsersSection onBack={onBack} />;
    case "server":
      return <ServerSection onBack={onBack} />;
    case "language":
      return <LanguageSection onBack={onBack} />;
    case "downloads":
      return <DownloadsSection onBack={onBack} />;
    case "two-factor":
      // the same screen the enrolment wall shows, so turning it on from
      // settings and being made to turn it on are one flow, not two
      return <TwoFactorSetup required={false} onDone={onBack} onBack={onBack} />;
    default:
      return <AboutSection onBack={onBack} />;
  }
}

function AccountSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const { user, refreshUser } = useSession();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");

  if (!user) return null;

  // the app's rules, checked here rather than only at the server, so the
  // answer arrives while the field is still in front of you
  const change = async () => {
    if (next !== confirm) {
      setError(t.passwordsDoNotMatch);
      return;
    }
    if (next.length < 10) {
      setError(t.passwordTooShort);
      return;
    }
    try {
      await api.patch(Api.mePassword, { current_password: current, new_password: next });
      toast(t.passwordChanged, "success");
      setOpen(false);
      setCurrent("");
      setNext("");
      setConfirm("");
      setError("");
      await refreshUser();
    } catch (e) {
      setError(e instanceof Error ? e.message : t.errorUnexpectedTitle);
    }
  };

  return (
    <Page title={t.settingsAccount} onBack={onBack}>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 14,
          padding: 18,
          background: "var(--bg-elevated)",
          border: "1px solid var(--stroke)",
          borderRadius: "var(--r-card)",
          marginBottom: 16,
        }}
      >
        <Avatar name={user.display_name || user.username} seed={user.avatar_seed} size={48} />
        <div style={{ minWidth: 0, flex: 1 }}>
          <div className="t-title-sm">{user.display_name || user.username}</div>
          <div className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
            {user.role === "admin" ? t.roleAdmin : t.roleMember}
          </div>
          {user.quota_bytes > 0 && (
            <>
              <div style={{ height: 5, borderRadius: 999, background: "var(--bg-sunken)", margin: "10px 0 6px", overflow: "hidden" }}>
                <div
                  style={{
                    height: "100%",
                    width: `${percent(user.quota_bytes_used, user.quota_bytes)}%`,
                    background: "var(--accent)",
                  }}
                />
              </div>
              <div className="t-label-sm" style={{ color: "var(--fg-secondary)" }}>
                {t.storageUsedOf({ used: bytes(user.quota_bytes_used), total: bytes(user.quota_bytes) })}
              </div>
            </>
          )}
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <Row glyph="user" label={t.usernameLabel} value={user.username} />
        {!HIDE_TWO_FACTOR && (
          <Row
            glyph="lock"
            label={t.settingsTwoFactor}
            value={user.totp_enabled ? t.twoFactorOn : t.twoFactorOff}
          />
        )}
        <Row glyph="lock" label={t.newPassword} onClick={() => setOpen(true)} />
      </div>

      <Sheet open={open} onClose={() => setOpen(false)} title={t.newPassword}>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <TextField
            value={current}
            onChange={setCurrent}
            label={t.currentPassword}
            hint={t.passwordHintExisting}
            type="password"
            glyph="lock"
          />
          <TextField
            value={next}
            onChange={setNext}
            label={t.newPassword}
            hint={t.passwordHintNew}
            type="password"
            glyph="lock"
          />
          <TextField
            value={confirm}
            onChange={setConfirm}
            label={t.confirmPasswordLabel}
            hint={t.confirmPasswordHint}
            type="password"
            glyph="lock"
          />
          {error && (
            <span className="t-body-sm" style={{ color: "var(--warning)" }}>
              {error}
            </span>
          )}
          <Button label={t.actionSave} onClick={() => void change()} />
        </div>
      </Sheet>
    </Page>
  );
}

function DevicesSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const [items, setItems] = useState<DeviceModel[] | null>(null);
  const toast = useToast();

  const load = async () => {
    try {
      const data = await api.get<{ sessions: DeviceModel[] }>(Api.sessions);
      setItems(data?.sessions ?? []);
    } catch {
      setItems([]);
    }
  };
  useEffect(() => {
    void load();
    // load() is stable for this screen's lifetime
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <Page title={t.devices} onBack={onBack}>
      {items === null ? (
        <ListSkeleton rows={4} />
      ) : items.length === 0 ? (
        <EmptyState glyph="device" title={t.emptyDevicesTitle} message={t.settingsRequireApprovalNote} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map((d) => (
            <div
              key={d.id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 14,
                padding: "14px 16px",
                background: "var(--bg-elevated)",
                border: `1px solid ${d.status === "pending" ? "var(--accent)" : "var(--stroke)"}`,
                borderRadius: "var(--r-card)",
              }}
            >
              <Icon glyph="device" size={19} color="var(--fg-secondary)" />
              <span style={{ flex: 1, minWidth: 0 }}>
                <span className="t-body-lg" style={{ display: "block" }}>
                  {d.device_name}{" "}
                  {d.current && <span style={{ color: "var(--accent)" }}>· {t.devicesThisDevice}</span>}
                </span>
                <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                  {d.status === "pending"
                    ? t.pendingApproval
                    : `${d.platform} · ${t.devicesLastSeen({ when: relative(d.last_seen_at) })}`}
                </span>
              </span>
              {d.status === "pending" ? (
                <Button
                  label={t.approve}
                  compact
                  expand={false}
                  onClick={async () => {
                    await api.post(`${Api.devices}/${d.id}/approve`, {});
                    toast(t.devicesApprovedToast, "success");
                    void load();
                  }}
                />
              ) : (
                !d.current && (
                  <Tappable
                    radius={999}
                    style={{ padding: 8, color: "var(--warning)" }}
                    title={t.devicesRevoke}
                    onClick={async () => {
                      await api.del(Api.session(d.id));
                      toast(t.devicesRevoke, "success");
                      void load();
                    }}
                  >
                    <Icon glyph="logout" size={18} />
                  </Tappable>
                )
              )}
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

function UsersSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const [items, setItems] = useState<UserModel[] | null>(null);
  useEffect(() => {
    void (async () => {
      try {
        const data = await api.get<{ users: UserModel[] }>(Api.adminUsers);
        setItems(data?.users ?? []);
      } catch {
        setItems([]);
      }
    })();
  }, []);

  return (
    <Page title={t.settingsUsers} onBack={onBack}>
      {items === null ? (
        <ListSkeleton rows={4} />
      ) : items.length === 0 ? (
        <EmptyState glyph="users" title={t.emptyUsersTitle} message={t.emptyUsersBody} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map((u) => (
            <div
              key={u.id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 14,
                padding: "14px 16px",
                background: "var(--bg-elevated)",
                border: "1px solid var(--stroke)",
                borderRadius: "var(--r-card)",
              }}
            >
              <Avatar name={u.display_name || u.username} seed={u.avatar_seed} />
              <span style={{ flex: 1, minWidth: 0 }}>
                <span className="t-body-lg" style={{ display: "block" }}>
                  {u.display_name || u.username}
                </span>
                <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                  {u.role === "admin" ? t.roleAdmin : t.roleMember} ·{" "}
                  {u.quota_bytes > 0
                    ? t.storageUsedOf({ used: bytes(u.quota_bytes_used), total: bytes(u.quota_bytes) })
                    : bytes(u.quota_bytes_used)}
                </span>
              </span>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

type ServerSettings = {
  server_name?: string;
  require_device_approval?: boolean;
  enable_lan_discovery?: boolean;
  allow_self_registration?: boolean;
};

function ServerSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const toast = useToast();
  const [current, setCurrent] = useState<ServerSettings | null>(null);
  const [renaming, setRenaming] = useState(false);
  const [name, setName] = useState("");

  useEffect(() => {
    void (async () => {
      try {
        setCurrent(await api.get<ServerSettings>(Api.settings));
      } catch {
        setCurrent({});
      }
    })();
  }, []);

  // sent one field at a time, and the switch only moves once the server has
  // agreed: a toggle that springs back is honest about what happened
  const apply = async (patch: ServerSettings) => {
    const previous = current;
    setCurrent({ ...current, ...patch });
    try {
      await api.patch(Api.settings, patch);
    } catch (e) {
      setCurrent(previous);
      toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
    }
  };

  if (!current) {
    return (
      <Page title={t.settingsServer} onBack={onBack}>
        <ListSkeleton rows={4} />
      </Page>
    );
  }

  return (
    <Page title={t.settingsServer} onBack={onBack}>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <SwitchRow
          glyph="device"
          label={t.settingsRequireApproval}
          description={t.settingsRequireApprovalNote}
          value={current.require_device_approval ?? false}
          onChange={(v) => void apply({ require_device_approval: v })}
        />
        <SwitchRow
          glyph="wifi"
          label={t.settingsLanDiscovery}
          description={t.settingsLanDiscoveryNote}
          value={current.enable_lan_discovery ?? false}
          onChange={(v) => void apply({ enable_lan_discovery: v })}
        />
        <SwitchRow
          glyph="users"
          label={t.settingsSelfRegistration}
          description={t.settingsSelfRegistrationNote}
          value={current.allow_self_registration ?? false}
          onChange={(v) => void apply({ allow_self_registration: v })}
        />
        <Row
          glyph="server"
          label={t.serverNameLabel}
          value={current.server_name ?? ""}
          onClick={() => {
            setName(current.server_name ?? "");
            setRenaming(true);
          }}
        />
      </div>

      <Sheet open={renaming} onClose={() => setRenaming(false)} title={t.serverNameLabel}>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <TextField value={name} onChange={setName} label={t.serverNameLabel} hint={t.serverNameHint} glyph="server" />
          <Button
            label={t.actionSave}
            onClick={async () => {
              await apply({ server_name: name.trim() });
              setRenaming(false);
            }}
          />
        </div>
      </Sheet>
    </Page>
  );
}

function LanguageSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const { locale, setLocale } = useSession();
  return (
    <Page title={t.settingsLanguage} onBack={onBack}>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <Row
          glyph="globe"
          label={t.languageEnglish}
          value={locale === "en" ? t.actionDone : ""}
          onClick={() => setLocale("en")}
        />
        <Row
          glyph="globe"
          label={t.languageArabic}
          value={locale === "ar" ? t.actionDone : ""}
          onClick={() => setLocale("ar")}
        />
      </div>
    </Page>
  );
}

function AboutSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const [status, setStatus] = useState<Record<string, unknown> | null>(null);
  const { server } = useSession();

  useEffect(() => {
    void (async () => {
      try {
        setStatus(await api.get<Record<string, unknown>>(Api.status));
      } catch {
        setStatus({});
      }
    })();
  }, []);

  return (
    <Page title={t.settingsAbout} onBack={onBack}>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <Row glyph="info" label={t.appName} value={String(status?.server_name ?? "")} />
        <Row glyph="server" label={t.serverNameLabel} value={server.replace(/^https?:\/\//, "")} />
        <Row glyph="info" label={t.versionInstalled} value={String(status?.version ?? "…")} />
      </div>
    </Page>
  );
}

/* --------------------------------------------------------------- downloads */

/**
 * Downloads on this device, ported from settings/widgets/offline_section.
 *
 * Deliberately separate from the server storage screen: this number is about
 * the browser in front of you and has nothing to do with the server's disks.
 */
function DownloadsSection({ onBack }: { onBack: () => void }) {
  const t = useL10n();
  const toast = useToast();
  const [data, setData] = useState<OfflineUsage | null>(null);
  const [confirming, setConfirming] = useState(false);

  const load = useCallback(() => {
    void usage().then(setData);
  }, []);

  useEffect(() => {
    load();
    window.addEventListener("ld-offline-changed", load);
    return () => window.removeEventListener("ld-offline-changed", load);
  }, [load]);

  if (!data) {
    return (
      <Page title={t.offlineDownloadsTitle} onBack={onBack}>
        <ListSkeleton rows={3} />
      </Page>
    );
  }

  return (
    <Page title={t.offlineDownloadsTitle} onBack={onBack}>
      <p className="t-body-sm" style={{ color: "var(--fg-secondary)", margin: "0 0 20px" }}>
        {t.offlineDownloadsBody}
      </p>

      {data.fileCount === 0 ? (
        <EmptyState glyph="offline" title={t.offlineNothingKept} message={t.offlineMakeAvailable} />
      ) : (
        <>
          <div
            style={{
              padding: 20,
              background: "var(--bg-elevated)",
              border: `1px solid ${data.overCap ? "var(--accent)" : "var(--stroke)"}`,
              borderRadius: "var(--r-card)",
            }}
          >
            <div className="t-display-sm">{bytes(data.totalBytes)}</div>
            <div className="t-body-sm" style={{ color: "var(--fg-secondary)", marginTop: 4 }}>
              {t.offlineFilesKept({ count: data.fileCount })}
            </div>
            {data.softCapBytes > 0 && (
              <>
                <div style={{ height: 5, borderRadius: 999, background: "var(--bg-sunken)", margin: "18px 0 8px", overflow: "hidden" }}>
                  <div
                    style={{
                      height: "100%",
                      width: `${percent(data.totalBytes, data.softCapBytes)}%`,
                      background: "var(--accent)",
                    }}
                  />
                </div>
                <div
                  className="t-label-sm"
                  style={{ color: data.overCap ? "var(--accent)" : "var(--fg-secondary)" }}
                >
                  {t.offlineSoftCapLabel} {bytes(data.softCapBytes)}
                </div>
              </>
            )}
          </div>

          <div style={{ marginTop: 22 }}>
            <div className="t-label-md" style={{ color: "var(--fg-secondary)", marginBottom: 10 }}>
              {t.offlineChosenIndividually}
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              {data.items.map((item) => (
                <div
                  key={item.id}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 12,
                    padding: "12px 14px",
                    background: "var(--bg-elevated)",
                    border: "1px solid var(--stroke)",
                    borderRadius: "var(--r-chip)",
                  }}
                >
                  <Icon glyph="file" size={18} color="var(--fg-secondary)" />
                  <span
                    className="t-body-md"
                    style={{ flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
                  >
                    {item.name || item.id}
                  </span>
                  <span className="t-label-sm" style={{ color: "var(--fg-secondary)" }}>
                    {bytes(item.bytes)}
                  </span>
                  <Tappable
                    radius={999}
                    style={{ padding: 6, color: "var(--warning)" }}
                    title={t.offlineRemoveDownload}
                    onClick={async () => {
                      await forget(item.id);
                      toast(t.offlineRemoved({ name: item.name || item.id }), "success");
                    }}
                  >
                    <Icon glyph="trash" size={16} />
                  </Tappable>
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      <div style={{ marginTop: 22 }}>
        <div className="t-label-md" style={{ color: "var(--fg-secondary)", marginBottom: 10 }}>
          {t.offlineSoftCapLabel}
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          {capChoices.map((choice) => (
            <Tappable
              key={choice}
              radius={12}
              onClick={() => setSoftCap(choice)}
              style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "11px 12px" }}
            >
              <span
                style={{
                  width: 18,
                  height: 18,
                  flex: "none",
                  borderRadius: 999,
                  border: `2px solid ${data.softCapBytes === choice ? "var(--accent)" : "var(--stroke)"}`,
                  display: "inline-flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                {data.softCapBytes === choice && (
                  <span style={{ width: 8, height: 8, borderRadius: 999, background: "var(--accent)" }} />
                )}
              </span>
              <span className="t-body-lg">{choice === 0 ? t.offlineNoLimit : bytes(choice)}</span>
            </Tappable>
          ))}
        </div>
      </div>

      {data.fileCount > 0 && (
        <div style={{ marginTop: 22 }}>
          <Button
            label={t.offlineClearAll}
            variant="danger"
            glyph="trash"
            onClick={() => setConfirming(true)}
          />
        </div>
      )}

      <Sheet open={confirming} onClose={() => setConfirming(false)} title={t.offlineClearAll}>
        <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 18px" }}>
          {t.offlineClearAllConfirm}
        </p>
        <div style={{ display: "flex", gap: 10 }}>
          <Button label={t.actionCancel} variant="quiet" onClick={() => setConfirming(false)} />
          <Button
            label={t.actionRemove}
            variant="danger"
            onClick={async () => {
              await forgetAll();
              setConfirming(false);
              toast(t.offlineCleared, "success");
            }}
          />
        </div>
      </Sheet>
    </Page>
  );
}

/* ---------------------------------------------------------------- storage */

export function StorageScreen() {
  const t = useL10n();
  const [items, setItems] = useState<LibraryModel[] | null>(null);
  const { user } = useSession();

  useEffect(() => {
    void (async () => {
      try {
        const data = await api.get<{ libraries: LibraryModel[] }>(Api.libraries);
        setItems(data?.libraries ?? []);
      } catch {
        setItems([]);
      }
    })();
  }, []);

  return (
    <Page title={t.storage}>
      {user && (
        <div
          style={{
            padding: 18,
            background: "var(--bg-elevated)",
            border: "1px solid var(--stroke)",
            borderRadius: "var(--r-card)",
            marginBottom: 20,
          }}
        >
          <div className="t-title-sm" style={{ marginBottom: 12 }}>
            {bytes(user.quota_bytes_used)} used
            {user.quota_bytes ? ` of ${bytes(user.quota_bytes)}` : ""}
          </div>
          <div style={{ height: 8, borderRadius: 999, background: "var(--bg-sunken)", overflow: "hidden" }}>
            <div
              style={{
                height: "100%",
                width: user.quota_bytes ? `${percent(user.quota_bytes_used, user.quota_bytes)}%` : "12%",
                background: "var(--accent)",
              }}
            />
          </div>
        </div>
      )}

      {items === null ? (
        <ListSkeleton rows={3} />
      ) : items.length === 0 ? (
        <EmptyState glyph="storage" title={t.storage} message={t.storageTotal} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map((l) => (
            <div
              key={l.id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 14,
                padding: "14px 16px",
                background: "var(--bg-elevated)",
                border: "1px solid var(--stroke)",
                borderRadius: "var(--r-card)",
              }}
            >
              <Icon glyph="storage" size={19} color={l.online ? "var(--accent)" : "var(--fg-muted)"} />
              <span style={{ flex: 1, minWidth: 0 }}>
                <span className="t-body-lg" style={{ display: "block" }}>
                  {l.name} {l.is_default && <span style={{ color: "var(--fg-secondary)" }}>· default</span>}
                </span>
                <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                  {l.online ? "Online" : "Offline"}
                  {l.free_bytes ? ` · ${bytes(l.free_bytes)} free` : ""}
                </span>
              </span>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

/* --------------------------------------------------------------- activity */

export function ActivityScreen() {
  const t = useL10n();
  const [items, setItems] = useState<{ id: string; action: string; created_at: number; username?: string }[] | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        const data = await api.get<{ entries?: unknown[]; activity?: unknown[] }>(Api.activity);
        const list = (data?.entries ?? data?.activity ?? []) as typeof items;
        setItems(list ?? []);
      } catch {
        setItems([]);
      }
    })();
  }, []);

  return (
    <Page title={t.activity}>
      {items === null ? (
        <ListSkeleton rows={6} />
      ) : items.length === 0 ? (
        <EmptyState glyph="activity" title={t.emptyActivityTitle} message={t.activity} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map((a) => (
            <div
              key={a.id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 14,
                padding: "12px 16px",
                background: "var(--bg-elevated)",
                border: "1px solid var(--stroke)",
                borderRadius: "var(--r-card)",
              }}
            >
              <Icon glyph="activity" size={18} color="var(--fg-secondary)" />
              <span style={{ flex: 1, minWidth: 0 }}>
                <span className="t-body-md" style={{ display: "block" }}>
                  {a.action.replace(/[._]/g, " ")}
                </span>
                <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                  {a.username ? `${a.username} · ` : ""}
                  {dateTime(a.created_at)}
                </span>
              </span>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}

/* -------------------------------------------------------------- transfers */

export { Page as SettingsPage };
