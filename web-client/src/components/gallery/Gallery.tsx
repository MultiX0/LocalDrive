"use client";

import { useEffect, useState } from "react";
import { useL10n } from "@/lib/l10n";
import { Icon } from "@/components/Icon";
import { EmptyState, ErrorState, GridSkeleton, Tappable } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { bytes } from "@/lib/format";
import type { NodeModel } from "@/lib/models";
import { transfers, type Transfer } from "@/lib/upload";

/**
 * The gallery: every photo and video in one timeline, grouped by month and
 * ordered by when it was taken rather than when it was uploaded.
 *
 * The grid is masonry, so a panorama stays a panorama instead of being cropped
 * to a square. That is the whole reason it is not the files grid with a filter.
 */
export function GalleryScreen({ onOpen }: { onOpen: (n: NodeModel) => void }) {
  const t = useL10n();
  const [nodes, setNodes] = useState<NodeModel[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    void (async () => {
      try {
        const data = await api.get<{ nodes: NodeModel[] }>(Api.nodes, { filter: "media" });
        setNodes(data?.nodes ?? []);
      } catch (e) {
        setError(e instanceof Error ? e.message : t.errorUnexpectedBody);
      }
    })();
  }, []);

  const groups = groupByMonth(nodes ?? []);

  return (
    <div style={{ minHeight: "100dvh" }}>
      <header
        style={{
          padding: "max(8px, env(safe-area-inset-top)) 16px 8px",
          position: "sticky",
          top: 0,
          background: "var(--bg-primary)",
          zIndex: 60,
        }}
      >
        <h1 className="t-title-lg" style={{ margin: 0 }}>
          Gallery
        </h1>
      </header>

      {error ? (
        <ErrorState message={error} />
      ) : nodes === null ? (
        <GridSkeleton />
      ) : nodes.length === 0 ? (
        <EmptyState glyph="gallery" title={t.galleryEmptyTitle} message={t.galleryEmptyBody} />
      ) : (
        <div style={{ padding: "8px 16px 120px" }}>
          {groups.map(([month, items]) => (
            <section key={month} style={{ marginBottom: 28 }}>
              <h2 className="t-label-md" style={{ color: "var(--fg-secondary)", margin: "0 0 10px" }}>
                {month}
              </h2>
              {/* masonry by columns, so tall pictures keep their shape */}
              <div style={{ columnWidth: 180, columnGap: 10 }}>
                {items.map((n) => (
                  <Tappable
                    key={n.id}
                    onClick={() => onOpen(n)}
                    radius={12}
                    style={{
                      display: "block",
                      width: "100%",
                      breakInside: "avoid",
                      marginBottom: 10,
                      overflow: "hidden",
                      border: "1px solid var(--stroke)",
                      background: "var(--bg-elevated)",
                      position: "relative",
                    }}
                  >
                    {n.has_thumbnail ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={api.media(Api.thumbnail(n.id))}
                        alt={n.name}
                        loading="lazy"
                        style={{ width: "100%", display: "block" }}
                      />
                    ) : (
                      <span style={{ display: "grid", placeItems: "center", height: 150 }}>
                        <Icon glyph={n.mime_type?.startsWith("video/") ? "video" : "image"} size={30} color="#4CC6C6" />
                      </span>
                    )}
                    {n.mime_type?.startsWith("video/") && (
                      <span
                        style={{
                          position: "absolute",
                          insetInlineEnd: 8,
                          bottom: 8,
                          background: "rgba(0,0,0,0.6)",
                          borderRadius: 999,
                          padding: 5,
                          display: "inline-flex",
                        }}
                      >
                        <Icon glyph="play" size={13} color="#FFFFFF" />
                      </span>
                    )}
                  </Tappable>
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

/** Grouped by the month it was taken, falling back to when it arrived. */
function groupByMonth(nodes: NodeModel[]): [string, NodeModel[]][] {
  const map = new Map<string, NodeModel[]>();
  const sorted = [...nodes].sort((a, b) => (b.taken_at || b.created_at) - (a.taken_at || a.created_at));
  for (const n of sorted) {
    const when = new Date(n.taken_at || n.created_at);
    const key = when.toLocaleDateString("en-GB", { month: "long", year: "numeric" });
    map.set(key, [...(map.get(key) ?? []), n]);
  }
  return [...map.entries()];
}

/* -------------------------------------------------------------- transfers */

export function TransfersScreen() {
  const t = useL10n();
  const [items, setItems] = useState<Transfer[]>([]);
  useEffect(() => {
    const stop = transfers.subscribe(setItems);
    return () => {
      stop();
    };
  }, []);

  return (
    <div style={{ minHeight: "100dvh" }}>
      <header
        style={{
          display: "flex",
          alignItems: "center",
          padding: "max(8px, env(safe-area-inset-top)) 16px 8px",
          position: "sticky",
          top: 0,
          background: "var(--bg-primary)",
          zIndex: 60,
        }}
      >
        <h1 className="t-title-lg" style={{ margin: 0, flex: 1 }}>
          Transfers
        </h1>
        {items.some((x) => x.state === "done") && (
          <Tappable onClick={() => transfers.clearFinished()} radius={10} style={{ padding: "8px 12px" }}>
            <span className="t-label-lg" style={{ color: "var(--accent)" }}>
              Clear finished
            </span>
          </Tappable>
        )}
      </header>

      <div style={{ padding: "8px 16px 120px" }}>
        {items.length === 0 ? (
          <EmptyState glyph="transfers" title={t.emptyTransfersTitle} message={t.emptyTransfersBody} />
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {items.map((item) => {
              const pct = item.size ? Math.round((item.sent / item.size) * 100) : 0;
              return (
                <div
                  key={item.id}
                  style={{
                    padding: "14px 16px",
                    background: "var(--bg-elevated)",
                    border: `1px solid ${item.state === "failed" ? "var(--warning)" : "var(--stroke)"}`,
                    borderRadius: "var(--r-card)",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <Icon
                      glyph={item.state === "failed" ? "alert" : item.state === "done" ? "check" : "upload"}
                      size={18}
                      color={item.state === "failed" ? "var(--warning)" : item.state === "done" ? "var(--accent)" : "var(--fg-secondary)"}
                    />
                    <span style={{ flex: 1, minWidth: 0 }}>
                      <span className="t-body-lg" style={{ display: "block", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {item.name}
                      </span>
                      <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                        {item.state === "failed"
                          ? item.error
                          : item.state === "done"
                            ? bytes(item.size)
                            : `${bytes(item.sent)} of ${bytes(item.size)}`}
                      </span>
                    </span>
                    {item.state === "uploading" && (
                      <span className="t-label-md" style={{ color: "var(--accent)" }}>
                        {pct}%
                      </span>
                    )}
                  </div>
                  {item.state === "uploading" && (
                    <div style={{ height: 4, borderRadius: 999, background: "var(--bg-sunken)", marginTop: 10, overflow: "hidden" }}>
                      <div style={{ height: "100%", width: `${pct}%`, background: "var(--accent)", transition: "width 200ms linear" }} />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
