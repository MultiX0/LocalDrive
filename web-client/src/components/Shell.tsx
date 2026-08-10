"use client";

import { useRef, type ReactNode } from "react";
import { useL10n, type Strings } from "@/lib/l10n";
import { Icon, type Glyph } from "./Icon";
import { Mark } from "./Mark";
import { Tappable, useDeviceClass } from "./ui";
import { bytes, percent } from "@/lib/format";
import { useSession } from "@/lib/session";

export type Section =
  | "files"
  | "gallery"
  | "shared"
  | "recent"
  | "starred"
  | "trash"
  | "storage"
  | "settings"
  | "search"
  | "transfers"
  | "activity";

/* The destinations name their string rather than carrying one, because a
   module level constant is built once and would freeze whichever language
   happened to be current then. */
const primary: { id: Section; key: keyof Strings; glyph: Glyph }[] = [
  { id: "files", key: "myFiles", glyph: "home" },
  { id: "gallery", key: "gallery", glyph: "gallery" },
  { id: "shared", key: "sharedWithMe", glyph: "shared" },
  { id: "recent", key: "recent", glyph: "recent" },
  { id: "starred", key: "starred", glyph: "star" },
  { id: "trash", key: "trash", glyph: "trash" },
  { id: "storage", key: "storage", glyph: "storage" },
  { id: "settings", key: "settings", glyph: "settings" },
];

/** What the bottom bar shows on a phone, where eight destinations do not fit. */
const compact: { id: Section; key: keyof Strings; glyph: Glyph }[] = [
  { id: "files", key: "navHome", glyph: "home" },
  { id: "gallery", key: "gallery", glyph: "gallery" },
  { id: "shared", key: "navShared", glyph: "shared" },
  { id: "settings", key: "navSettings", glyph: "settings" },
];

export function Shell({
  section,
  onNavigate,
  onUpload,
  children,
}: {
  section: Section;
  onNavigate: (s: Section) => void;
  /** given the picked files. The input lives here rather than in the files
   *  browser, because the sidebar and the phone's plus button have to reach it
   *  from Settings, Gallery and everywhere else too. */
  onUpload: (files: FileList | null) => void;
  children: ReactNode;
}) {
  const t = useL10n();
  const { isMobile } = useDeviceClass();
  const { user } = useSession();
  const shellFileInput = useRef<HTMLInputElement>(null);
  const pick = () => shellFileInput.current?.click();

  if (isMobile) {
    return (
      <div style={{ minHeight: "100dvh", display: "flex", flexDirection: "column" }}>
        <input ref={shellFileInput} type="file" multiple hidden onChange={(e) => { onUpload(e.target.files); e.target.value = ""; }} />
        <div style={{ flex: 1, minHeight: 0, paddingBottom: 92 }}>{children}</div>
        <nav
          style={{
            position: "fixed",
            insetInline: 12,
            bottom: "calc(12px + env(safe-area-inset-bottom))",
            height: 68,
            display: "flex",
            alignItems: "center",
            justifyContent: "space-around",
            background: "var(--bg-elevated)",
            border: "1px solid var(--stroke)",
            borderRadius: "var(--r-pill)",
            zIndex: 500,
          }}
        >
          {compact.slice(0, 2).map((item) => (
            <BottomItem key={item.id} item={item} active={section === item.id} onClick={() => onNavigate(item.id)} />
          ))}
          <Tappable
            onClick={pick}
            radius={999}
            style={{
              width: 52,
              height: 52,
              background: "var(--accent)",
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
            }}
            title={t.upload}
          >
            <Icon glyph="plus" size={24} color="#FFFFFF" />
          </Tappable>
          {compact.slice(2).map((item) => (
            <BottomItem key={item.id} item={item} active={section === item.id} onClick={() => onNavigate(item.id)} />
          ))}
        </nav>
      </div>
    );
  }

  return (
    <div style={{ minHeight: "100dvh", display: "flex" }}>
      <input ref={shellFileInput} type="file" multiple hidden onChange={(e) => { onUpload(e.target.files); e.target.value = ""; }} />
      <aside
        style={{
          width: 248,
          flex: "none",
          borderInlineEnd: "1px solid var(--stroke)",
          padding: "18px 14px",
          display: "flex",
          flexDirection: "column",
          gap: 6,
          position: "sticky",
          top: 0,
          height: "100dvh",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 8px 14px" }}>
          <Mark size={26} />
          <span className="t-title-sm">{t.appName}</span>
        </div>

        <Tappable
          onClick={pick}
          radius={24}
          style={{
            height: 46,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            background: "var(--accent)",
            color: "#FFFFFF",
            marginBottom: 10,
          }}
        >
          <Icon glyph="upload" size={18} color="#FFFFFF" />
          <span className="t-label-lg">{t.upload}</span>
        </Tappable>

        {primary.map((item) => {
          const active = section === item.id;
          return (
            <Tappable
              key={item.id}
              onClick={() => onNavigate(item.id)}
              radius={14}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 12,
                padding: "12px 14px",
                background: active ? "rgba(76,141,255,0.12)" : "transparent",
                color: active ? "var(--accent)" : "var(--fg-secondary)",
                border: `1px solid ${active ? "rgba(76,141,255,0.35)" : "transparent"}`,
              }}
            >
              <Icon glyph={item.glyph} size={19} />
              <span className="t-body-lg" style={{ fontWeight: active ? 600 : 400 }}>
                {String(t[item.key])}
              </span>
            </Tappable>
          );
        })}

        <div style={{ flex: 1 }} />
        {user && <QuotaBar used={user.quota_bytes_used} total={user.quota_bytes} />}
      </aside>

      <main style={{ flex: 1, minWidth: 0 }}>{children}</main>
    </div>
  );
}

function BottomItem({
  item,
  active,
  onClick,
}: {
  item: { id: Section; key: keyof Strings; glyph: Glyph };
  active: boolean;
  onClick: () => void;
}) {
  const t = useL10n();
  return (
    <Tappable
      onClick={onClick}
      radius={14}
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 3,
        padding: "6px 12px",
        color: active ? "var(--accent)" : "var(--fg-secondary)",
        minWidth: 60,
      }}
    >
      <Icon glyph={item.glyph} size={20} />
      <span className="t-label-sm">{String(t[item.key])}</span>
    </Tappable>
  );
}

/** Quota, or just what has been used when the account has no limit. */
function QuotaBar({ used, total }: { used: number; total: number }) {
  const t = useL10n();
  const unlimited = !total || total <= 0;
  const pct = percent(used, total);
  return (
    <div style={{ padding: "12px 10px" }}>
      <div
        style={{
          height: 4,
          borderRadius: 999,
          background: "var(--bg-elevated)",
          overflow: "hidden",
          marginBottom: 8,
        }}
      >
        <div
          style={{
            height: "100%",
            width: unlimited ? "12%" : `${pct}%`,
            background: pct > 90 ? "var(--warning)" : "var(--accent)",
            transition: "width var(--d-standard) var(--ease)",
          }}
        />
      </div>
      <div className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
        {unlimited
          ? t.sidebarStorageUsed({ used: bytes(used) })
          : t.storageUsedOf({ used: bytes(used), total: bytes(total) })}
      </div>
    </div>
  );
}
