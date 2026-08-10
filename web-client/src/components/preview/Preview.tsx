"use client";

import { useEffect, useState } from "react";
import { Icon } from "@/components/Icon";
import { EmptyState, ErrorState, Spinner, Tappable } from "@/components/ui";
import { api } from "@/lib/api";
import { Api } from "@/lib/endpoints";
import { bytes } from "@/lib/format";
import { useL10n } from "@/lib/l10n";
import { categoryOf, type NodeModel } from "@/lib/models";
import { readKept } from "@/lib/offline";

/**
 * The preview, ported from features/preview/pages/preview_page.dart.
 *
 * Same set of kinds it handles: image, video, audio, pdf, text, code with line
 * numbers, and markdown rendered rather than shown as source. Anything else
 * gets a download, because a viewer that renders nothing is worse than none.
 */
export function Preview({ node, onClose }: { node: NodeModel; onClose: () => void }) {
  const t = useL10n();
  const category = categoryOf(node);
  const [local, setLocal] = useState<string>("");

  // a kept copy is read before the network, so a file marked available offline
  // opens with the server unreachable
  useEffect(() => {
    let url = "";
    void (async () => {
      const blob = await readKept(node.id);
      if (blob) {
        url = URL.createObjectURL(blob);
        setLocal(url);
      }
    })();
    return () => {
      if (url) URL.revokeObjectURL(url);
    };
  }, [node.id]);

  const src = local || api.media(Api.download(node.id));
  const isMarkdown = /\.(md|markdown)$/i.test(node.name);
  const textual = category === "code" || category === "document" || isTextual(node.mime_type);
  const online = useOnline();
  // not kept, and no connection to fetch it with. Say that plainly rather than
  // spinning forever or looking broken
  const unreachable = !online && !local;

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 900,
        background: "rgba(0,0,0,0.86)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "clamp(12px, 3vw, 28px)",
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{ width: "100%", maxWidth: 1100, display: "flex", flexDirection: "column", minHeight: 0 }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 12 }}>
          <span
            className="t-title-md"
            style={{ flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
          >
            {node.name}
          </span>
          <span className="t-body-sm" style={{ color: "var(--fg-secondary)" }}>
            {bytes(node.size_bytes)}
          </span>
          <a href={src} download title={t.download} style={{ display: "inline-flex", padding: 8, color: "var(--accent)" }}>
            <Icon glyph="download" size={19} />
          </a>
          <Tappable onClick={onClose} radius={999} style={{ padding: 8 }} title={t.actionCancel}>
            <Icon glyph="close" size={19} />
          </Tappable>
        </div>

        <div
          style={{
            background: "var(--bg-sunken)",
            border: "1px solid var(--stroke)",
            borderRadius: "var(--r-card)",
            overflow: "hidden",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            minHeight: 240,
            maxHeight: "78vh",
          }}
        >
          {unreachable ? (
            <EmptyState glyph="offline" title={node.name} message={t.offlineNeedsConnection} />
          ) : category === "image" ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={src} alt={node.name} style={{ maxWidth: "100%", maxHeight: "78vh", display: "block" }} />
          ) : category === "video" ? (
            <video src={src} controls autoPlay style={{ width: "100%", maxHeight: "78vh", background: "#000" }} />
          ) : category === "audio" ? (
            <div style={{ width: "100%", padding: 28, textAlign: "center" }}>
              <Icon glyph="audio" size={46} color="#4CC6C6" />
              <div className="t-title-sm" style={{ margin: "14px 0 18px" }}>
                {node.name}
              </div>
              <audio src={src} controls autoPlay style={{ width: "100%" }} />
            </div>
          ) : category === "pdf" ? (
            <iframe src={src} title={node.name} style={{ width: "100%", height: "78vh", border: 0 }} />
          ) : textual ? (
            <TextView node={node} markdown={isMarkdown} lineNumbers={category === "code"} />
          ) : (
            <EmptyState
              glyph="file"
              title={t.previewCannotPreview}
              message={t.previewDownloadToOpen}
            />
          )}
        </div>
      </div>
    </div>
  );
}

/** Whether the browser thinks it can reach anything. It is a hint rather than
 *  proof, which is why a kept copy is still tried first. */
function useOnline(): boolean {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    const sync = () => setOnline(navigator.onLine);
    sync();
    window.addEventListener("online", sync);
    window.addEventListener("offline", sync);
    return () => {
      window.removeEventListener("online", sync);
      window.removeEventListener("offline", sync);
    };
  }, []);
  return online;
}

/** A mime type a person can read as characters. */
function isTextual(mime: string): boolean {
  const m = (mime || "").toLowerCase();
  return (
    m.startsWith("text/") ||
    m.includes("json") ||
    m.includes("xml") ||
    m.includes("yaml") ||
    m.includes("javascript") ||
    m.includes("typescript") ||
    m.includes("x-sh") ||
    m.includes("x-python") ||
    m.includes("csv")
  );
}

/**
 * Text, code and markdown.
 *
 * Fetched with the session's own header rather than a token in the url: this
 * is a request the page makes itself, so it can carry one properly.
 *
 * Capped, because a browser asked to lay out a 200 MB log will stop
 * responding, and nobody reads that in a preview anyway.
 */
const MAX_PREVIEW_BYTES = 512 * 1024;

function TextView({
  node,
  markdown,
  lineNumbers,
}: {
  node: NodeModel;
  markdown: boolean;
  lineNumbers: boolean;
}) {
  const t = useL10n();
  const [text, setText] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [truncated, setTruncated] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetch(api.absolute(Api.download(node.id)), {
          headers: { Authorization: `Bearer ${localStorage.getItem("ld.access") ?? ""}` },
        });
        if (!res.ok) throw new Error(`The server returned ${res.status}.`);
        const raw = await res.text();
        if (cancelled) return;
        setTruncated(raw.length > MAX_PREVIEW_BYTES);
        setText(raw.slice(0, MAX_PREVIEW_BYTES));
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : t.errorUnexpectedBody);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [node.id]);

  if (error) return <ErrorState message={error} />;
  if (text === null)
    return (
      <div style={{ padding: 48 }}>
        <Spinner />
      </div>
    );

  const body = markdown ? (
    <div className="t-body-lg" style={{ lineHeight: 1.7 }} dangerouslySetInnerHTML={{ __html: renderMarkdown(text) }} />
  ) : lineNumbers ? (
    <table style={{ borderCollapse: "collapse", width: "100%" }}>
      <tbody>
        {text.split("\n").map((line, i) => (
          <tr key={i}>
            <td
              style={{
                width: 1,
                whiteSpace: "nowrap",
                textAlign: "end",
                paddingInlineEnd: 14,
                color: "var(--fg-muted)",
                userSelect: "none",
                verticalAlign: "top",
              }}
            >
              {i + 1}
            </td>
            <td style={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{line || " "}</td>
          </tr>
        ))}
      </tbody>
    </table>
  ) : (
    <pre style={{ margin: 0, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{text}</pre>
  );

  return (
    <div
      style={{
        width: "100%",
        maxHeight: "78vh",
        overflow: "auto",
        padding: 20,
        textAlign: "start",
        fontFamily: markdown ? "inherit" : "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
        fontSize: 13.5,
        lineHeight: 1.65,
      }}
      dir="ltr"
    >
      {body}
      {truncated && (
        <div className="t-body-sm" style={{ color: "var(--fg-secondary)", marginTop: 16 }}>
          Showing the first {bytes(MAX_PREVIEW_BYTES)}. Download the file to read the rest.
        </div>
      )}
    </div>
  );
}

/**
 * Enough markdown to read a README: headings, bold, italic, inline code,
 * fenced code, links, lists and rules.
 *
 * Deliberately small and escaped first. Rendering somebody else's file means
 * rendering somebody else's html, so nothing reaches the page as markup that
 * did not come from this function.
 */
function renderMarkdown(source: string): string {
  const esc = (s: string) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

  const blocks: string[] = [];
  let text = esc(source).replace(/```([\s\S]*?)```/g, (_m, code) => {
    blocks.push(String(code));
    return `\u0000${blocks.length - 1}\u0000`;
  });

  text = text
    .replace(/^###### (.*)$/gm, "<h6>$1</h6>")
    .replace(/^##### (.*)$/gm, "<h5>$1</h5>")
    .replace(/^#### (.*)$/gm, "<h4>$1</h4>")
    .replace(/^### (.*)$/gm, "<h3>$1</h3>")
    .replace(/^## (.*)$/gm, "<h2>$1</h2>")
    .replace(/^# (.*)$/gm, "<h1>$1</h1>")
    .replace(/^\s*---+\s*$/gm, "<hr>")
    .replace(/`([^`\n]+)`/g, '<code style="background:#0E0E0E;padding:2px 6px;border-radius:6px">$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*\n]+)\*/g, "<em>$1</em>")
    // only http and https, so a javascript: url cannot ride in on a link
    .replace(
      /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g,
      '<a href="$2" target="_blank" rel="noopener noreferrer" style="color:#4C8DFF">$1</a>',
    )
    .replace(/^\s*[-*+] (.*)$/gm, "<li>$1</li>")
    .replace(/(<li>[\s\S]*?<\/li>)(?!\s*<li>)/g, "<ul style='padding-inline-start:20px'>$1</ul>")
    .replace(/\n{2,}/g, "<br><br>");

  return text.replace(/\u0000(\d+)\u0000/g, (_m, i) => {
    const code = blocks[Number(i)] ?? "";
    return `<pre style="background:#0E0E0E;border:1px solid #3D3D3D;border-radius:12px;padding:14px;overflow:auto"><code>${code.replace(/^\w*\n/, "")}</code></pre>`;
  });
}
