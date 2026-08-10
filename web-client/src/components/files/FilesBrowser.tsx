"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Icon, type Glyph } from "@/components/Icon";
import {
  Avatar,
  Button,
  Dialog,
  EmptyState,
  ErrorState,
  GridSkeleton,
  ListSkeleton,
  Menu,
  Sheet,
  Tappable,
  TextField,
  UtilityButton,
  useDeviceClass,
  useToast,
} from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { bytes, extensionOf, relative } from "@/lib/format";
import { categoryOf, isFolder, type NodeModel } from "@/lib/models";
import { colorForCategory, folderSwatches, wash } from "@/lib/tokens";
import { useKeptIds } from "@/lib/offline";
import { useUploader } from "@/lib/uploads";
import { ShareSheet } from "@/components/share/ShareSheet";
import { DetailsPane } from "./DetailsPane";
import { bandStyle, hasPointer, rangeBetween, useFileKeys, useMarquee, useNodeDrag } from "./desktop";
import { useL10n, type Strings } from "@/lib/l10n";

type ViewMode = "grid" | "list";

const glyphForCategory: Record<string, Glyph> = {
  folder: "folder",
  image: "image",
  video: "video",
  audio: "audio",
  pdf: "pdf",
  spreadsheet: "sheet",
  presentation: "slides",
  code: "code",
  archive: "archive",
  document: "file",
  other: "file",
};

export function FilesBrowser({
  folderId,
  filter,
  title,
  onOpenFolder,
  onPreview,
}: {
  folderId: string;
  filter: "none" | "starred" | "recent" | "trash" | "shared";
  title: string;
  onOpenFolder: (node: NodeModel) => void;
  onPreview: (node: NodeModel) => void;
}) {
  const t = useL10n();
  const [nodes, setNodes] = useState<NodeModel[] | null>(null);
  const [error, setError] = useState("");
  const [view, setView] = useState<ViewMode>("grid");
  const [selection, setSelection] = useState<Set<string>>(new Set());
  const [query, setQuery] = useState("");
  const [menu, setMenu] = useState<{ x: number; y: number; node: NodeModel } | null>(null);
  const [overflow, setOverflow] = useState<{ x: number; y: number } | null>(null);
  const [searching, setSearching] = useState(false);
  const [sharing, setSharing] = useState<NodeModel | null>(null);
  const [dragging, setDragging] = useState(false);
  const toast = useToast();
  const { isDesktop, isMobile } = useDeviceClass();
  const fileInput = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const anchor = useRef<string | null>(null);

  const [createFolderOpen, setCreateFolderOpen] = useState(false);
  const [folderName, setFolderName] = useState("");
  const [renamingNode, setRenamingNode] = useState<NodeModel | null>(null);
  const [renameName, setRenameName] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleCreateFolder = async () => {
    if (!folderName.trim()) return;
    setIsSubmitting(true);
    try {
      await api.post(Api.folder, { name: folderName.trim(), parent_id: folderId });
      setCreateFolderOpen(false);
      setFolderName("");
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRename = async () => {
    if (!renamingNode || !renameName.trim()) return;
    setIsSubmitting(true);
    try {
      await api.patch(Api.node(renamingNode.id), { name: renameName.trim() });
      setRenamingNode(null);
      setRenameName("");
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : t.errorUnexpectedTitle, "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  const load = useCallback(async () => {
    setError("");
    setNodes(null);
    try {
      // The trash is its own endpoint, not a filter. /nodes accepts shared,
      // starred and recent only, and quietly ignores anything else: asking it
      // for "trash" returned the whole drive, which looked like every file had
      // been deleted.
      const data =
        filter === "trash"
          ? await api.get<{ nodes: NodeModel[] }>(Api.trash)
          : await api.get<{ nodes: NodeModel[] }>(Api.nodes, {
              parent_id: filter === "none" ? folderId : "",
              filter: filter === "none" ? undefined : filter,
              query: query || undefined,
            });
      setNodes(data?.nodes ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : t.errorUnexpectedBody);
    }
  }, [folderId, filter, query, t]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setSelection(new Set());
  }, [folderId, filter]);

  const visible = useMemo(() => nodes ?? [], [nodes]);

  const toggle = (id: string, additive: boolean, range = false) => {
    if (range) {
      // shift extends from the last thing clicked, the way a file list has
      // behaved since long before any of this
      const ids = rangeBetween(visible.map((n) => n.id), anchor.current, id);
      setSelection(new Set(ids));
      return;
    }
    anchor.current = id;
    setSelection((prev) => {
      const next = new Set(additive ? prev : []);
      if (prev.has(id) && additive) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const activate = (node: NodeModel) => {
    if (isFolder(node)) onOpenFolder(node);
    else onPreview(node);
  };

  const { pick: upload, sheet: clashSheet, busy: resolvingClash } = useUploader(folderId, () => {
    toast(t.transferCompleted, "success");
    void load();
  });

  const chosen = visible.filter((n) => selection.has(n.id));

  const trashChosen = useCallback(async () => {
    const list = visible.filter((n) => selection.has(n.id));
    if (!list.length) return;
    for (const node of list) {
      try {
        await api.del(Api.node(node.id));
      } catch {
        /* reported once, below */
      }
    }
    toast(t.confirmTrashTitle, "success");
    setSelection(new Set());
    void load();
  }, [visible, selection, toast, load]);

  // the rubber band, and the keys a file manager is expected to answer to
  const band = useMarquee({
    containerRef: listRef,
    itemSelector: "[data-node-id]",
    onChange: useCallback((ids: string[], additive: boolean) => {
      setSelection((prev) => (additive ? new Set([...prev, ...ids]) : new Set(ids)));
    }, []),
    onEmptyClick: useCallback(() => setSelection(new Set()), []),
  });

  // anything layered over the grid owns the keyboard while it is up: Escape has
  // to dismiss the sheet, not silently empty the selection underneath it
  const layered =
    sharing !== null || renamingNode !== null || createFolderOpen || menu !== null || overflow !== null || resolvingClash;

  useFileKeys({
    onSelectAll: useCallback(() => setSelection(new Set(visible.map((n) => n.id))), [visible]),
    onDelete: () => void trashChosen(),
    onEscape: useCallback(() => setSelection(new Set()), []),
    enabled: !layered,
  });

  const { over, dragProps, folderProps } = useNodeDrag(
    useCallback(
      async (ids: string[], intoFolderId: string) => {
        for (const id of ids) {
          try {
            await api.patch(Api.node(id), { parent_id: intoFolderId });
          } catch {
            /* a move the server refuses stays where it was */
          }
        }
        toast(t.actionMove, "success");
        setSelection(new Set());
        void load();
      },
      [toast, load],
    ),
    // dropped straight onto a folder tile, so it lands there rather than in
    // whatever folder happens to be open
    useCallback(
      (files: FileList, intoFolderId: string) => {
        void upload(files, intoFolderId);
      },
      [upload],
    ),
  );

  return (
    <div
      style={{ minHeight: "100dvh", display: "flex", flexDirection: "column", position: "relative" }}
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        void upload(e.dataTransfer.files);
      }}
      // clearing on a click into nothing belongs to the marquee, which knows
      // whether the press became a drag. A second handler here fired after
      // every rubber band and wiped what it had just selected.
    >
      {/*
        FilesToolbar. The title is titleLarge and takes the free width; the
        controls sit at the trailing end after a 16 gap, so a long folder name
        never touches the first button.

        A phone keeps the one control people reach for constantly and folds the
        rest into a menu: four buttons at the minimum tap size plus their gaps
        eat 216 of about 375 points and leave the name a stub.
      */}
      <header
        style={{
          display: "flex",
          alignItems: "center",
          padding: isDesktop
            ? "4px 24px 8px"
            : "max(8px, env(safe-area-inset-top)) 16px 8px",
          position: "sticky",
          top: 0,
          background: "var(--bg-primary)",
          zIndex: 60,
        }}
      >
        {/* the name keeps its width and the free space goes between it and the
            controls, so a folder name is never squeezed to an ellipsis while
            the toolbar has room to spare */}
        <h1
          className="t-title-lg"
          style={{
            margin: 0,
            flex: "0 1 auto",
            minWidth: 0,
            maxWidth: "42%",
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {title}
        </h1>
        <span style={{ flex: 1, minWidth: 16 }} />

        {isMobile ? (
          <span style={{ display: "inline-flex", gap: 4 }}>
            <UtilityButton glyph="search" title={t.search} onClick={() => setSearching((s) => !s)} />
            <UtilityButton
              glyph="more"
              title={t.moreActions}
              onClick={(e) => setOverflow({ x: e.clientX, y: e.clientY })}
            />
          </span>
        ) : !isDesktop ? (
          /* tablet: the same controls as desktop but with search as an icon.
             The wide field belongs to the desktop scaffold, and forcing it in
             here squeezes the folder name down to an ellipsis. */
          <span style={{ display: "inline-flex", gap: 8, alignItems: "center" }}>
            <UtilityButton glyph="search" title={t.search} onClick={() => setSearching((s) => !s)} />
            <UtilityButton glyph="sort" title={t.sortBy} onClick={() => undefined} />
            <UtilityButton
              glyph={view === "grid" ? "list" : "grid"}
              title={view === "grid" ? "List view" : "Grid view"}
              onClick={() => setView((v) => (v === "grid" ? "list" : "grid"))}
            />
            <UtilityButton glyph="folder-plus" title={t.newFolder} onClick={() => { setFolderName(""); setCreateFolderOpen(true); }} />
          </span>
        ) : (
          <span style={{ display: "inline-flex", gap: 8, alignItems: "center" }}>
            {/* the desktop scaffold carries a persistent search field, not an
                icon: a wide window has the room, and leaving the folder to see
                matches means losing the breadcrumb and the place you were */}
            <span
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                height: 44,
                padding: "0 14px",
                width: 320,
                background: "var(--bg-elevated)",
                border: "1px solid var(--stroke)",
                borderRadius: "var(--r-pill)",
                marginInlineEnd: 4,
              }}
            >
              <Icon glyph="search" size={17} color="var(--fg-secondary)" />
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={t.search}
                style={{
                  flex: 1,
                  minWidth: 0,
                  background: "transparent",
                  border: 0,
                  outline: "none",
                  color: "var(--fg-primary)",
                  font: "inherit",
                  fontSize: 14,
                }}
              />
            </span>
            <UtilityButton glyph="sort" title={t.sortBy} onClick={() => undefined} />
            <UtilityButton
              glyph={view === "grid" ? "list" : "grid"}
              title={view === "grid" ? "List view" : "Grid view"}
              onClick={() => setView((v) => (v === "grid" ? "list" : "grid"))}
            />
            <UtilityButton glyph="folder-plus" title={t.newFolder} onClick={() => { setFolderName(""); setCreateFolderOpen(true); }} />
            <Button label={t.upload} glyph="upload" compact expand={false} onClick={() => fileInput.current?.click()} />
          </span>
        )}
      </header>

      {searching && (
        <div style={{ padding: "0 16px 8px" }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              height: 44,
              padding: "0 14px",
              background: "var(--bg-elevated)",
              border: "1px solid var(--stroke)",
              borderRadius: "var(--r-pill)",
            }}
          >
            <Icon glyph="search" size={17} color="var(--fg-secondary)" />
            <input
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.search}
              style={{
                flex: 1,
                background: "transparent",
                border: 0,
                outline: "none",
                color: "var(--fg-primary)",
                font: "inherit",
                fontSize: 14,
              }}
            />
          </div>
        </div>
      )}

      <input
        ref={fileInput}
        type="file"
        multiple
        hidden
        onChange={(e) => void upload(e.target.files)}
      />

      {/* the selection bar floats over the listing, so the listing starts below it */}
      {chosen.length > 0 && (
        <div
          onClick={(e) => e.stopPropagation()}
          className="ld-enter"
          style={{
            position: "absolute",
            insetInline: 16,
            top: isDesktop ? 84 : 92,
            zIndex: 70,
            display: "flex",
            alignItems: "center",
            gap: 10,
            padding: "10px 12px",
            background: "var(--bg-elevated)",
            border: "1px solid var(--accent)",
            borderRadius: "var(--r-pill)",
          }}
        >
          <Tappable onClick={() => setSelection(new Set())} radius={999} style={{ padding: 6 }}>
            <Icon glyph="close" size={18} />
          </Tappable>
          <span className="t-title-sm" style={{ flex: 1 }}>
            {t.selectedCount({ count: chosen.length })}
          </span>
          <Tappable onClick={() => setSelection(new Set(visible.map((n) => n.id)))} radius={999} style={{ padding: 6 }} title={t.actionSelect}>
            <Icon glyph="check" size={18} />
          </Tappable>
          {chosen.length === 1 && (
            <Tappable
              radius={999}
              style={{ padding: 6 }}
              title={t.moreActions}
              onClick={(e) => setMenu({ x: e.clientX, y: e.clientY, node: chosen[0] })}
            >
              <Icon glyph="more" size={18} />
            </Tappable>
          )}
          <Tappable
            radius={999}
            style={{ padding: 6, color: "var(--warning)" }}
            title={t.confirmTrashTitle}
            onClick={async () => {
              for (const node of chosen) {
                try {
                  await api.del(Api.node(node.id));
                } catch {
                  /* reported below, once */
                }
              }
              toast(t.confirmTrashTitle, "success");
              setSelection(new Set());
              void load();
            }}
          >
            <Icon glyph="trash" size={18} />
          </Tappable>
        </div>
      )}

      {/* listing */}
      <div ref={listRef} style={{ flex: 1, minHeight: 0, paddingTop: chosen.length ? 56 : 0 }}>
        {error ? (
          <ErrorState message={error} onRetry={() => void load()} />
        ) : nodes === null ? (
          view === "grid" ? <GridSkeleton /> : <ListSkeleton />
        ) : visible.length === 0 ? (
          <EmptyState
            glyph={filter === "trash" ? "trash" : filter === "starred" ? "star" : "folder"}
            title={emptyTitle(filter, t)}
            message={emptyBody(filter, t)}
            actionLabel={filter === "none" ? "Upload a file" : undefined}
            onAction={filter === "none" ? () => fileInput.current?.click() : undefined}
          />
        ) : view === "grid" ? (
          <Grid nodes={visible} selection={selection} onToggle={toggle} onActivate={activate} onMenu={setMenu} dragProps={dragProps} folderProps={folderProps} over={over} />
        ) : (
          <List nodes={visible} selection={selection} onToggle={toggle} onActivate={activate} onMenu={setMenu} dragProps={dragProps} folderProps={folderProps} over={over} />
        )}
      </div>

      {/* exactly one selected opens the pane; several means a bulk action is
          in progress and one item's details would describe the wrong thing */}
      {isDesktop && chosen.length === 1 && (
        <DetailsPane
          node={chosen[0]}
          onClose={() => setSelection(new Set())}
          onOpen={activate}
          onChanged={() => void load()}
          onShare={(n) => setSharing(n)}
        />
      )}

      {sharing && <ShareSheet node={sharing} onClose={() => setSharing(null)} />}

      {clashSheet}

      {band && <div style={bandStyle(band)} />}

      {/* drop overlay: the whole surface, so "let go anywhere" needs no reading */}
      {dragging && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            zIndex: 400,
            background: wash("#4C8DFF", 0.1),
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            pointerEvents: "none",
          }}
        >
          <div
            style={{
              padding: "32px 40px",
              background: "var(--bg-elevated)",
              border: "2px solid var(--accent)",
              borderRadius: "var(--r-card)",
              textAlign: "center",
            }}
          >
            <Icon glyph="upload" size={44} color="var(--accent)" />
            <div className="t-title-md" style={{ marginTop: 16 }}>
              Drop to upload
            </div>
          </div>
        </div>
      )}

      {/* what the phone folds away, rather than cramming into the row */}
      <Menu
        open={Boolean(overflow)}
        x={overflow?.x ?? 0}
        y={overflow?.y ?? 0}
        onClose={() => setOverflow(null)}
        items={[
          {
            label: view === "grid" ? "List view" : "Grid view",
            glyph: view === "grid" ? "list" : "grid",
            onClick: () => setView((v) => (v === "grid" ? "list" : "grid")),
          },
          { label: t.sortBy, glyph: "sort", onClick: () => undefined },
          { label: t.newFolder, glyph: "folder-plus", onClick: () => { setFolderName(""); setCreateFolderOpen(true); } },
          { label: t.upload, glyph: "upload", onClick: () => fileInput.current?.click() },
          { label: t.actionRefresh, glyph: "refresh", onClick: () => void load() },
        ]}
      />

      <Menu
        open={Boolean(menu)}
        x={menu?.x ?? 0}
        y={menu?.y ?? 0}
        onClose={() => setMenu(null)}
        items={
          menu
            ? [
                { label: t.actionOpen, glyph: "eye", onClick: () => activate(menu.node) },
                {
                  label: t.download,
                  glyph: "download",
                  onClick: () => window.open(api.media(Api.download(menu.node.id)), "_blank"),
                },
                {
                  label: menu.node.starred ? "Remove star" : "Star",
                  glyph: "star",
                  onClick: async () => {
                    await api.post(Api.star(menu.node.id), { starred: !menu.node.starred });
                    void load();
                  },
                },
                {
                  label: t.actionRename,
                  glyph: "rename",
                  onClick: () => {
                    setRenamingNode(menu.node);
                    setRenameName(menu.node.name);
                  },
                },
                {
                  label: t.confirmTrashTitle,
                  glyph: "trash",
                  danger: true,
                  onClick: async () => {
                    await api.del(Api.node(menu.node.id));
                    toast(t.confirmTrashTitle, "success");
                    void load();
                  },
                },
              ]
            : []
        }
      />

      <Dialog open={createFolderOpen} onClose={() => setCreateFolderOpen(false)} title={t.newFolder}>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void handleCreateFolder();
          }}
          style={{ display: "flex", flexDirection: "column", gap: 20 }}
        >
          <TextField
            autoFocus
            value={folderName}
            onChange={setFolderName}
            label={t.folderNameLabel}
            hint={t.folderNameHint}
          />
          <div style={{ display: "flex", gap: 12, justifyContent: "flex-end" }}>
            <Button label={t.actionCancel} variant="quiet" expand={false} compact onClick={() => setCreateFolderOpen(false)} />
            <Button label={t.actionSave} variant="primary" expand={false} compact busy={isSubmitting} type="submit" />
          </div>
        </form>
      </Dialog>

      <Dialog open={Boolean(renamingNode)} onClose={() => setRenamingNode(null)} title={t.actionRename}>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void handleRename();
          }}
          style={{ display: "flex", flexDirection: "column", gap: 20 }}
        >
          <TextField
            autoFocus
            value={renameName}
            onChange={setRenameName}
            label={t.renameTo}
          />
          <div style={{ display: "flex", gap: 12, justifyContent: "flex-end" }}>
            <Button label={t.actionCancel} variant="quiet" expand={false} compact onClick={() => setRenamingNode(null)} />
            <Button label={t.actionSave} variant="primary" expand={false} compact busy={isSubmitting} type="submit" />
          </div>
        </form>
      </Dialog>
    </div>
  );
}

function emptyTitle(filter: string, t: Strings) {
  switch (filter) {
    case "starred":
      return t.emptyStarredTitle;
    case "recent":
      return t.emptyRecentTitle;
    case "trash":
      return t.emptyTrashTitle;
    case "shared":
      return t.emptySharedTitle;
    default:
      return t.emptyFolderTitle;
  }
}

function emptyBody(filter: string, t: Strings) {
  switch (filter) {
    case "starred":
      return t.emptyStarredBody;
    case "recent":
      return t.emptyRecentBody;
    case "trash":
      return t.emptyTrashBody;
    case "shared":
      return t.emptySharedBody;
    default:
      return t.emptyFolderBody;
  }
}

/* ------------------------------------------------------------------- grid */

function Grid({
  nodes,
  selection,
  onToggle,
  onActivate,
  onMenu,
  dragProps,
  folderProps,
  over,
}: {
  nodes: NodeModel[];
  selection: Set<string>;
  onToggle: (id: string, additive: boolean, range?: boolean) => void;
  onActivate: (n: NodeModel) => void;
  onMenu: (m: { x: number; y: number; node: NodeModel }) => void;
  dragProps: (id: string, sel: Set<string>) => Record<string, unknown>;
  folderProps: (id: string) => Record<string, unknown>;
  over: string;
}) {
  const kept = useKeptIds();
  return (
    <div
      style={{
        display: "grid",
        // sized by how wide a tile should be, not by how many should fit
        gridTemplateColumns: "repeat(auto-fill, minmax(170px, 1fr))",
        gap: 16,
        padding: "20px 20px 120px",
      }}
    >
      {nodes.map((node) => (
        <Tile
          key={node.id}
          node={node}
          selected={selection.has(node.id)}
          onToggle={onToggle}
          onActivate={onActivate}
          onMenu={onMenu}
          dragProps={dragProps}
          folderProps={folderProps}
          over={over}
          selection={selection}
          kept={kept.has(node.id)}
        />
      ))}
    </div>
  );
}

function Tile({
  node,
  selected,
  onToggle,
  onActivate,
  onMenu,
  dragProps,
  folderProps,
  over,
  selection,
  kept,
}: {
  node: NodeModel;
  selected: boolean;
  onToggle: (id: string, additive: boolean, range?: boolean) => void;
  onActivate: (n: NodeModel) => void;
  onMenu: (m: { x: number; y: number; node: NodeModel }) => void;
  dragProps: (id: string, sel: Set<string>) => Record<string, unknown>;
  folderProps: (id: string) => Record<string, unknown>;
  over: string;
  selection: Set<string>;
  kept: boolean;
}) {
  const t = useL10n();
  const category = categoryOf(node);
  const tone = isFolder(node) && node.color ? folderSwatches[node.color] ?? colorForCategory(category) : colorForCategory(category);
  const ext = extensionOf(node.name);

  return (
    <div
      data-node-id={node.id}
      {...dragProps(node.id, selection)}
      {...(isFolder(node) ? folderProps(node.id) : {})}
      onClick={(e) => {
        e.stopPropagation();
        if (e.detail >= 2) onActivate(node);
        else onToggle(node.id, e.ctrlKey || e.metaKey, e.shiftKey);
      }}
      onDoubleClick={() => onActivate(node)}
      onContextMenu={(e) => {
        e.preventDefault();
        e.stopPropagation();
        onMenu({ x: e.clientX, y: e.clientY, node });
      }}
      style={{ cursor: "pointer" }}
    >
      <div
        style={{
          position: "relative",
          aspectRatio: "1 / 1",
          borderRadius: "var(--r-tile)",
          border: `1px solid ${over === node.id || selected ? "var(--accent)" : "var(--stroke)"}`,
          // a folder lights up while something is held over it
          background: over === node.id ? "rgba(76,141,255,0.12)" : "var(--bg-elevated)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          overflow: "hidden",
          transition: "border-color var(--d-hover) var(--ease)",
        }}
      >
        {node.has_thumbnail ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={api.media(Api.thumbnail(node.id))}
            alt=""
            loading="lazy"
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        ) : (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
            {/* a folder reads as a solid shape, the way it does in the app; a
                file keeps the outline glyph in its type colour */}
            {isFolder(node) ? (
              <svg viewBox="0 0 24 24" width={52} height={52} aria-hidden="true">
                <path
                  d="M3 7.5A1.5 1.5 0 0 1 4.5 6h4l2 2.5h7A1.5 1.5 0 0 1 19 10v7.5a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 3 17.5z"
                  fill={node.color ? tone : "var(--fg-muted)"}
                />
              </svg>
            ) : (
              <Icon glyph={glyphForCategory[category] ?? "file"} size={44} color={tone} />
            )}
            {ext && !isFolder(node) && (
              <span className="t-label-sm" style={{ color: "var(--fg-secondary)" }}>
                {ext}
              </span>
            )}
          </div>
        )}

        {selected && (
          <span
            style={{
              position: "absolute",
              insetInlineEnd: 8,
              top: 8,
              width: 22,
              height: 22,
              borderRadius: 999,
              background: "var(--accent)",
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Icon glyph="check" size={14} color="#FFFFFF" strokeWidth={2.6} />
          </span>
        )}
        {/* top-left is the owner's corner, and only ever appears on something
            someone else owns */}
        {node.owner && (
          <span style={{ position: "absolute", insetInlineStart: 6, top: 6 }} title={node.owner.name}>
            <Avatar name={node.owner.name} seed={node.owner.avatar_seed} size={26} showBorder />
          </span>
        )}

        {/* top-right holds one thing at a time: the selection tick while
            choosing, then the offline mark, then the shared mark */}
        {kept && !selected && (
          <span
            style={{
              position: "absolute",
              insetInlineEnd: 8,
              top: 8,
              width: 20,
              height: 20,
              borderRadius: 999,
              background: "var(--accent)",
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
            }}
            title={t.offlineRemoveDownload}
          >
            <Icon glyph="check" size={13} color="#FFFFFF" strokeWidth={2.6} />
          </span>
        )}
        {node.shared && !selected && !kept && (
          <span style={{ position: "absolute", insetInlineEnd: 8, top: 8 }}>
            <Icon glyph="share" size={15} color="var(--accent)" />
          </span>
        )}
      </div>

      <div className="t-body-md" style={{ marginTop: 10, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
        {node.name}
      </div>
      <div className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
        {isFolder(node) ? relative(node.updated_at) : bytes(node.size_bytes)}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------- list */

/**
 * The two facts under a name, joined with a middot rather than a space: run
 * together, "300 KB 2 hours ago" reads as one broken phrase.
 *
 * A folder has no size worth printing, and whose it is outranks when it changed
 * on something shared with you.
 */
function subtitleFor(node: NodeModel): string {
  const join = (a: string, b: string) => [a, b].filter(Boolean).join(" · ");
  const when = relative(node.updated_at);
  if (isFolder(node)) return node.owner ? join(node.owner.name, when) : when;
  const size = bytes(node.size_bytes);
  return node.owner ? join(node.owner.name, size) : join(size, when);
}

function List({
  nodes,
  selection,
  onToggle,
  onActivate,
  onMenu,
  dragProps,
  folderProps,
  over,
}: {
  nodes: NodeModel[];
  selection: Set<string>;
  onToggle: (id: string, additive: boolean, range?: boolean) => void;
  onActivate: (n: NodeModel) => void;
  onMenu: (m: { x: number; y: number; node: NodeModel }) => void;
  dragProps: (id: string, sel: Set<string>) => Record<string, unknown>;
  folderProps: (id: string) => Record<string, unknown>;
  over: string;
}) {
  const kept = useKeptIds();
  return (
    <div style={{ padding: "12px 16px 120px" }}>
      {nodes.map((node) => {
        const category = categoryOf(node);
        const tone = colorForCategory(category);
        const selected = selection.has(node.id);
        return (
          <div
            key={node.id}
            data-node-id={node.id}
            {...dragProps(node.id, selection)}
            {...(isFolder(node) ? folderProps(node.id) : {})}
            onClick={(e) => {
              e.stopPropagation();
              if (e.detail >= 2) onActivate(node);
              else onToggle(node.id, e.ctrlKey || e.metaKey, e.shiftKey);
            }}
            onDoubleClick={() => onActivate(node)}
            onContextMenu={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onMenu({ x: e.clientX, y: e.clientY, node });
            }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 14,
              padding: "10px 12px",
              borderRadius: "var(--r-chip)",
              border: `1px solid ${over === node.id || selected ? "var(--accent)" : "transparent"}`,
              background: over === node.id || selected ? wash("#4C8DFF", 0.1) : "transparent",
              cursor: "pointer",
            }}
          >
            <span
              style={{
                width: 40,
                height: 40,
                flex: "none",
                borderRadius: 10,
                background: "var(--bg-elevated)",
                border: "1px solid var(--stroke)",
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                overflow: "hidden",
              }}
            >
              {node.has_thumbnail ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={api.media(Api.thumbnail(node.id))} alt="" loading="lazy" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              ) : (
                <Icon glyph={glyphForCategory[category] ?? "file"} size={19} color={tone} />
              )}
            </span>
            <span style={{ flex: 1, minWidth: 0 }}>
              <span className="t-body-lg" style={{ display: "block", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {node.name}
              </span>
              <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
                {subtitleFor(node)}
              </span>
            </span>
            {kept.has(node.id) && <Icon glyph="offline" size={16} color="var(--accent)" />}
            {node.starred && <Icon glyph="star-filled" size={16} color="var(--accent)" />}
          </div>
        );
      })}
    </div>
  );
}
