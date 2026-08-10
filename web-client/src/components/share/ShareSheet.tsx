"use client";

import { useCallback, useEffect, useState } from "react";
import { Icon } from "@/components/Icon";
import { Button, initialsOf, Sheet, Spinner, Tappable, TextField, useToast } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { dateTime } from "@/lib/format";
import { useL10n } from "@/lib/l10n";
import type { DirectoryUser, NodeModel, ShareModel } from "@/lib/models";

/**
 * Sharing, ported from features/share.
 *
 * Two tabs, the same two the app has: a link anyone can open, and people on
 * this server. A link's password, expiry and download setting are all editable
 * in place without the url changing, so one already sent stays the same while
 * what it permits changes.
 */
export function ShareSheet({ node, onClose }: { node: NodeModel; onClose: () => void }) {
  const t = useL10n();
  const [tab, setTab] = useState<"link" | "people">("link");

  return (
    <Sheet open onClose={onClose} title={`${t.actionShare} · ${node.name}`}>
      <div
        style={{
          display: "flex",
          gap: 4,
          padding: 4,
          background: "var(--bg-sunken)",
          border: "1px solid var(--stroke)",
          borderRadius: "var(--r-pill)",
          marginBottom: 18,
        }}
      >
        {(["link", "people"] as const).map((id) => {
          const active = tab === id;
          return (
            <Tappable
              key={id}
              onClick={() => setTab(id)}
              radius={999}
              style={{
                flex: 1,
                padding: "10px 0",
                textAlign: "center",
                background: active ? "var(--accent)" : "transparent",
                color: active ? "#FFFFFF" : "var(--fg-secondary)",
              }}
            >
              <span className="t-label-lg">{id === "link" ? t.shareLinkTab : t.sharePeopleTab}</span>
            </Tappable>
          );
        })}
      </div>

      {tab === "link" ? <LinkTab node={node} /> : <PeopleTab node={node} />}
    </Sheet>
  );
}

/* ------------------------------------------------------------------ link */

function LinkTab({ node }: { node: NodeModel }) {
  const t = useL10n();
  const toast = useToast();
  const [share, setShare] = useState<ShareModel | null>(null);
  const [loading, setLoading] = useState(true);
  const [allowDownload, setAllowDownload] = useState(true);
  const [password, setPassword] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get<{ shares?: ShareModel[] }>(Api.nodeShares(node.id));
      const first = data?.shares?.[0] ?? null;
      setShare(first);
      if (first) setAllowDownload(first.allow_download);
    } catch {
      setShare(null);
    } finally {
      setLoading(false);
    }
  }, [node.id]);

  useEffect(() => {
    void load();
  }, [load]);

  const create = async () => {
    try {
      const made = await api.post<ShareModel>(Api.createShare(node.id), {
        allow_download: allowDownload,
        ...(password ? { password } : {}),
      });
      setShare(made);
      setPassword("");
      toast(t.actionCopyLink, "success");
    } catch (e) {
      toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
    }
  };

  const update = async (patch: Record<string, unknown>) => {
    if (!share) return;
    try {
      // the url never changes, so a link already sent keeps working while what
      // it permits changes underneath it
      const next = await api.patch<ShareModel>(Api.share(share.id), patch);
      setShare(next ?? share);
      toast(t.actionSave, "success");
    } catch (e) {
      toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
    }
  };

  if (loading)
    return (
      <div style={{ display: "grid", placeItems: "center", padding: 32 }}>
        <Spinner />
      </div>
    );

  if (!share) {
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        <Toggle
          label={t.shareLinkAllowDownload}
          value={allowDownload}
          onChange={setAllowDownload}
        />
        <TextField
          value={password}
          onChange={setPassword}
          label={t.shareLinkPassword}
          hint={t.shareLinkPasswordHint}
          type="password"
          glyph="lock"
        />
        <Button label={t.shareLinkTab} glyph="link" onClick={create} />
      </div>
    );
  }

  const url = api.publicLink(share.url || Api.publicShare(share.token));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
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
        <Icon glyph="link" size={17} color="var(--fg-secondary)" />
        <span
          className="t-body-sm"
          dir="ltr"
          style={{ flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
        >
          {url}
        </span>
        <Tappable
          radius={8}
          style={{ padding: 6, color: "var(--accent)" }}
          title={t.actionCopyLink}
          onClick={async () => {
            try {
              await navigator.clipboard.writeText(url);
              toast(t.actionCopied, "success");
            } catch {
              toast(t.errorUnexpectedTitle, "error");
            }
          }}
        >
          <Icon glyph="copy" size={17} />
        </Tappable>
      </div>

      <Toggle
        label={t.shareLinkAllowDownload}
        value={share.allow_download}
        onChange={(v) => void update({ allow_download: v })}
      />

      <Row
        label={t.shareLinkExpiry}
        value={share.expires_at ? dateTime(share.expires_at) : t.neverExpires}
      />
      <Row
        label={t.shareLinkPassword}
        value={share.password_protected ? t.shareLinkPassword : t.shareLinkNoPassword}
      />

      <Button
        label={t.actionRemove}
        variant="danger"
        glyph="trash"
        onClick={async () => {
          await api.del(Api.share(share.id));
          setShare(null);
          toast(t.actionRemove, "success");
        }}
      />
    </div>
  );
}

/* ---------------------------------------------------------------- people */

function PeopleTab({ node }: { node: NodeModel }) {
  const t = useL10n();
  const toast = useToast();
  const [users, setUsers] = useState<DirectoryUser[] | null>(null);
  const [granted, setGranted] = useState<Record<string, string>>({});

  useEffect(() => {
    void (async () => {
      try {
        const [all, grants] = await Promise.all([
          api.get<{ users?: DirectoryUser[] }>(Api.users),
          api.get<{ grants?: { user_id: string; role: string }[] }>(Api.permissions(node.id)),
        ]);
        setUsers(all?.users ?? []);
        const map: Record<string, string> = {};
        for (const g of grants?.grants ?? []) map[g.user_id] = g.role;
        setGranted(map);
      } catch {
        setUsers([]);
      }
    })();
  }, [node.id]);

  if (users === null)
    return (
      <div style={{ display: "grid", placeItems: "center", padding: 32 }}>
        <Spinner />
      </div>
    );

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <p className="t-body-sm" style={{ color: "var(--fg-secondary)", margin: "0 0 6px" }}>
        {t.sharePeopleHint}
      </p>
      {users.map((u) => {
        const role = granted[u.id];
        return (
          <Tappable
            key={u.id}
            radius={12}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              width: "100%",
              padding: "12px 14px",
              border: `1px solid ${role ? "var(--accent)" : "var(--stroke)"}`,
              background: "var(--bg-elevated)",
            }}
            onClick={async () => {
              try {
                if (role) {
                  await api.del(Api.permission(node.id, u.id));
                  setGranted((g) => {
                    const next = { ...g };
                    delete next[u.id];
                    return next;
                  });
                } else {
                  await api.post(Api.permissions(node.id), { user_id: u.id, role: "viewer" });
                  setGranted((g) => ({ ...g, [u.id]: "viewer" }));
                }
              } catch (e) {
                toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
              }
            }}
          >
            <span
              style={{
                width: 36,
                height: 36,
                flex: "none",
                borderRadius: 999,
                background: "rgba(76,141,255,0.16)",
                border: "1px solid var(--accent)",
                color: "var(--accent)",
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                fontWeight: 700,
                fontSize: 13,
              }}
            >
              {initialsOf(u.name)}
            </span>
            <span style={{ flex: 1, minWidth: 0 }}>
              <span className="t-body-lg" style={{ display: "block" }}>
                {u.name}
              </span>
              <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                {role ? t.shareRoleViewer : ""}
              </span>
            </span>
            {role && <Icon glyph="check" size={17} color="var(--accent)" />}
          </Tappable>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ bits */

function Toggle({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <Tappable
      onClick={() => onChange(!value)}
      radius={12}
      style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "6px 2px" }}
    >
      <span className="t-body-lg" style={{ flex: 1 }}>
        {label}
      </span>
      <span
        style={{
          width: 44,
          height: 26,
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

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
      <span className="t-body-lg" style={{ flex: 1 }}>
        {label}
      </span>
      <span className="t-body-md" style={{ color: "var(--fg-secondary)" }}>
        {value}
      </span>
    </div>
  );
}
