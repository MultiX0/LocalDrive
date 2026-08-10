"use client";

import { useCallback, useState } from "react";
import { Button, Sheet } from "@/components/ui";
import { api } from "./api";
import { Api } from "./endpoints";
import { useL10n } from "./l10n";
import { isFolder, type NodeModel } from "./models";
import { transfers } from "./upload";

/**
 * Picking files, including the question that has to be asked when a name is
 * already taken. Ported from upload/widgets/duplicate_sheet.
 *
 * It lives here rather than in the files browser because two places start an
 * upload: the button in the shell and the browser's own drop target. Two
 * copies of this rule would eventually disagree, and the one that forgot to
 * ask would silently make a second file instead of a new version.
 */
export function useUploader(parentId: string, onDone?: () => void) {
  const t = useL10n();
  const [clash, setClash] = useState<{
    files: File[];
    clashes: File[];
    existing: Map<string, NodeModel>;
    into: string;
  } | null>(null);

  const send = useCallback(
    async (list: File[], into: string, replacing?: Map<File, string>) => {
      if (!list.length) return;
      await transfers.enqueue(list, into, onDone, replacing);
    },
    [onDone],
  );

  const pick = useCallback(
    /** `into` overrides the destination, for files dropped straight onto a
     *  folder tile rather than into the folder on screen. */
    async (files: FileList | File[] | null, into = parentId) => {
      const list = files ? Array.from(files) : [];
      if (!list.length) return;

      // failing to read the destination is not a reason to block an upload:
      // the server renames rather than overwrites, so the worst case is a
      // second file rather than a lost one
      let siblings: NodeModel[] = [];
      try {
        const data = await api.get<{ nodes: NodeModel[] }>(Api.nodes, { parent_id: into });
        siblings = data?.nodes ?? [];
      } catch {
        await send(list, into);
        return;
      }

      // names compare without case, the same way the server decides a clash,
      // so Photo.PNG and photo.png are recognised as the same name
      const existing = new Map(
        siblings.filter((n) => !isFolder(n)).map((n) => [n.name.toLowerCase(), n] as const),
      );
      const clashes = list.filter((f) => existing.has(f.name.toLowerCase()));
      if (!clashes.length) {
        await send(list, into);
        return;
      }
      setClash({ files: list, clashes, existing, into });
    },
    [parentId, send],
  );

  // one question for the whole batch: asking per file would mean twelve
  // identical sheets for twelve photos dropped at once
  const sheet = clash ? (
    <Sheet
      open
      onClose={() => setClash(null)}
      title={clash.clashes.length === 1 ? t.uploadClashTitle : t.uploadClashTitleMany}
    >
      <p className="t-body-md" style={{ color: "var(--fg-secondary)", margin: "0 0 18px" }}>
        {clash.clashes.length === 1
          ? t.uploadClashBody({ name: clash.clashes[0].name })
          : t.uploadClashBodyMany({ count: clash.clashes.length })}
      </p>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <Button
          label={t.uploadClashKeepBoth}
          glyph="copy"
          onClick={() => {
            // every file goes up under its own name; the server is what
            // renames the second one, not this screen
            const all = clash.files;
            setClash(null);
            void send(all, clash.into);
          }}
        />
        <Button
          label={t.uploadClashReplace}
          glyph="upload"
          onClick={() => {
            const replacing = new Map<File, string>();
            for (const file of clash.clashes) {
              const node = clash.existing.get(file.name.toLowerCase());
              if (node) replacing.set(file, node.id);
            }
            const all = clash.files;
            setClash(null);
            void send(all, clash.into, replacing);
          }}
        />
        <Button
          label={t.uploadClashSkip}
          variant="quiet"
          onClick={() => {
            // the ones that did not clash still go
            const rest = clash.files.filter((f) => !clash.clashes.includes(f));
            setClash(null);
            void send(rest, clash.into);
          }}
        />
        <Button label={t.actionCancel} variant="quiet" onClick={() => setClash(null)} />
      </div>
    </Sheet>
  ) : null;

  return { pick, sheet, busy: clash !== null };
}
