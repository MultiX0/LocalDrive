"use client";

import { useEffect, useState } from "react";
import { Icon, type Glyph } from "@/components/Icon";
import { Tappable, useToast } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { bytes, dateTime, relative } from "@/lib/format";
import { useL10n } from "@/lib/l10n";
import { categoryOf, isFolder, type NodeModel } from "@/lib/models";
import { colorForCategory } from "@/lib/tokens";
import { forget, isKept, keep } from "@/lib/offline";

/**
 * The details pane, ported from features/files/widgets/desktop/node_details_pane.
 *
 * Opens when exactly one thing is selected. Several means a bulk action is in
 * progress, and one item's details would be describing the wrong thing.
 *
 * It floats over the listing rather than sitting beside it, so opening it never
 * resizes the grid and reflows the tiles under the pointer.
 */
export function DetailsPane({
  node,
  onClose,
  onOpen,
  onChanged,
  onShare,
}: {
  node: NodeModel;
  onClose: () => void;
  onOpen: (n: NodeModel) => void;
  onChanged: () => void;
  onShare: (n: NodeModel) => void;
}) {
  const t = useL10n();
  const toast = useToast();
  const category = categoryOf(node);
  const tone = colorForCategory(category);
  const [versions, setVersions] = useState<{ id: string; size_bytes: number; created_at: number }[]>([]);
  const [kept, setKept] = useState(false);

  useEffect(() => setKept(isKept(node.id)), [node.id]);

  // versions are a file's own history, so a folder has none to ask about
  useEffect(() => {
    if (isFolder(node)) {
      setVersions([]);
      return;
    }
    let cancelled = false;
    void (async () => {
      try {
        const data = await api.get<{ versions?: typeof versions }>(Api.versions(node.id));
        if (!cancelled) setVersions(data?.versions ?? []);
      } catch {
        if (!cancelled) setVersions([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [node.id]);

  return (
    <aside
      onClick={(e) => e.stopPropagation()}
      className="ld-enter"
      style={{
        position: "absolute",
        insetInlineEnd: 0,
        top: 0,
        bottom: 0,
        width: "var(--detail-pane)",
        background: "var(--bg-primary)",
        borderInlineStart: "1px solid var(--stroke)",
        zIndex: 80,
        overflowY: "auto",
        padding: 20,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
        <span
          className="t-title-sm"
          style={{ flex: 1, minWidth: 0, overflowWrap: "anywhere" }}
        >
          {node.name}
        </span>
        <Tappable onClick={onClose} radius={999} style={{ padding: 6 }} title={t.actionCancel}>
          <Icon glyph="close" size={18} />
        </Tappable>
      </div>

      <div
        style={{
          aspectRatio: "4 / 3",
          borderRadius: "var(--r-tile)",
          border: "1px solid var(--stroke)",
          background: "var(--bg-elevated)",
          display: "grid",
          placeItems: "center",
          overflow: "hidden",
          marginBottom: 18,
        }}
      >
        {node.has_thumbnail ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={api.media(Api.thumbnail(node.id))}
            alt=""
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        ) : (
          <Icon glyph={isFolder(node) ? "folder" : "file"} size={44} color={tone} />
        )}
      </div>

      <Facts node={node} />

      <div style={{ display: "flex", flexDirection: "column", gap: 6, marginTop: 18 }}>
        <Action glyph="eye" label={t.actionOpen} onClick={() => onOpen(node)} />
        {!isFolder(node) && (
          <Action
            glyph="download"
            label={t.download}
            onClick={() => window.open(api.media(Api.download(node.id)), "_blank")}
          />
        )}
        <Action
          glyph="star"
          label={node.starred ? t.actionRemove : t.starred}
          onClick={async () => {
            if (node.starred) await api.del(Api.star(node.id));
            else await api.post(Api.star(node.id), {});
            onChanged();
          }}
        />
        <Action glyph="share" label={t.actionShare} onClick={() => onShare(node)} />
        {!isFolder(node) && (
          <Action
            glyph="offline"
            label={kept ? t.offlineRemoveDownload : t.offlineMakeAvailable}
            onClick={async () => {
              try {
                if (kept) {
                  await forget(node.id);
                  setKept(false);
                  toast(t.offlineRemoved({ name: node.name }), "success");
                } else {
                  const ok = await keep(node.id, node.name);
                  if (!ok) {
                    toast(t.errorUnexpectedTitle, "error");
                    return;
                  }
                  setKept(true);
                  toast(t.offlineQueued({ name: node.name }), "success");
                }
              } catch (e) {
                toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
              }
            }}
          />
        )}
        <Action
          glyph="rename"
          label={t.actionRename}
          onClick={async () => {
            const name = window.prompt(t.actionRename, node.name);
            if (!name || name === node.name) return;
            await api.patch(Api.node(node.id), { name });
            onChanged();
          }}
        />
        <Action
          glyph="trash"
          label={t.confirmTrashTitle}
          danger
          onClick={async () => {
            await api.del(Api.node(node.id));
            toast(t.confirmTrashTitle, "success");
            onClose();
            onChanged();
          }}
        />
      </div>

      {/* the endpoint returns the versions that came before, so the count on
          the node is what says there is any history at all */}
      {!isFolder(node) && (node.version_count ?? 1) > 1 && versions.length > 0 && (
        <div style={{ marginTop: 22 }}>
          <div className="t-label-md" style={{ color: "var(--fg-secondary)", marginBottom: 10 }}>
            {t.versionHistory}
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {versions.map((v) => (
              <div
                key={v.id}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  padding: "10px 12px",
                  border: "1px solid var(--stroke)",
                  borderRadius: "var(--r-chip)",
                  background: "var(--bg-elevated)",
                }}
              >
                <Icon glyph="restore" size={16} color="var(--fg-secondary)" />
                <span style={{ flex: 1, minWidth: 0 }}>
                  <span className="t-body-md" style={{ display: "block" }}>
                    {relative(v.created_at)}
                  </span>
                  <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                    {bytes(v.size_bytes)}
                  </span>
                </span>
                <Tappable
                  radius={8}
                  style={{ padding: "6px 8px", color: "var(--accent)" }}
                  title={t.restore}
                  onClick={async () => {
                    // restoring keeps the current bytes as a version of their
                    // own, so the move is itself reversible
                    await api.post(Api.restoreVersion(node.id, v.id), {});
                    toast(t.versionRestored, "success");
                    onChanged();
                  }}
                >
                  <span className="t-label-lg">{t.restore}</span>
                </Tappable>
              </div>
            ))}
          </div>
        </div>
      )}
    </aside>
  );
}

function Facts({ node }: { node: NodeModel }) {
  const t = useL10n();
  const rows: [string, string][] = [
    [t.sortName, node.name],
    [t.sortSize, isFolder(node) ? "—" : bytes(node.size_bytes)],
    [t.gallerySortModified, relative(node.updated_at)],
    [t.gallerySortAdded, dateTime(node.created_at)],
  ];
  if (node.image_width && node.image_height) {
    rows.splice(2, 0, ["", `${node.image_width} × ${node.image_height}`]);
  }
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      {rows.map(([k, v], i) => (
        <div key={i} style={{ display: "flex", gap: 12 }}>
          <span className="t-body-sm" style={{ color: "var(--fg-muted)", width: 92, flex: "none" }}>
            {k}
          </span>
          <span className="t-body-md" style={{ overflowWrap: "anywhere" }}>
            {v}
          </span>
        </div>
      ))}
    </div>
  );
}

function Action({
  glyph,
  label,
  onClick,
  danger,
}: {
  glyph: Glyph;
  label: string;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <Tappable
      onClick={onClick}
      radius={12}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        width: "100%",
        padding: "11px 12px",
        color: danger ? "var(--warning)" : "var(--fg-primary)",
      }}
    >
      <Icon glyph={glyph} size={18} color={danger ? "var(--warning)" : "var(--fg-secondary)"} />
      <span className="t-body-lg" style={{ flex: 1 }}>
        {label}
      </span>
      <Icon glyph="chevron-right" size={16} color="var(--fg-muted)" />
    </Tappable>
  );
}
