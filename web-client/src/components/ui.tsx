"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { Icon, type Glyph } from "./Icon";

/*
  The shared widgets, matching the Ld* set in the Flutter client.

  Flat fills with a one pixel border, no shadows and no gradients. Two accents
  only. Every surface here should be recognisable beside a screenshot of the
  app, because it is the same design system rather than an interpretation of it.
*/

/* ------------------------------------------------------------------ press */

/** A pressable surface with the app's press feedback: a brief fade, not a
 *  ripple. Used instead of a bare button so every tap feels the same. */
export function Tappable({
  children,
  onClick,
  onContextMenu,
  className = "",
  radius = 12,
  disabled,
  title,
  style,
}: {
  children: ReactNode;
  onClick?: (e: React.MouseEvent) => void;
  onContextMenu?: (e: React.MouseEvent) => void;
  className?: string;
  radius?: number;
  disabled?: boolean;
  title?: string;
  style?: React.CSSProperties;
}) {
  return (
    <button
      type="button"
      title={title}
      disabled={disabled}
      onClick={onClick}
      onContextMenu={onContextMenu}
      className={`ld-tappable ${className}`}
      style={{
        borderRadius: radius,
        background: "none",
        border: 0,
        padding: 0,
        color: "inherit",
        font: "inherit",
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? 0.5 : 1,
        transition: `background var(--d-tap) var(--ease), opacity var(--d-tap) var(--ease)`,
        textAlign: "start",
        ...style,
      }}
    >
      {children}
    </button>
  );
}

/* ----------------------------------------------------------------- button */

export function Button({
  label,
  onClick,
  glyph,
  variant = "primary",
  expand = true,
  compact = false,
  disabled,
  busy,
  type = "button",
}: {
  label: string;
  onClick?: () => void;
  glyph?: Glyph;
  variant?: "primary" | "quiet" | "danger";
  expand?: boolean;
  compact?: boolean;
  disabled?: boolean;
  busy?: boolean;
  type?: "button" | "submit";
}) {
  const palette = {
    primary: { bg: "var(--accent)", fg: "#FFFFFF", border: "var(--accent)" },
    quiet: { bg: "transparent", fg: "var(--fg-primary)", border: "var(--stroke)" },
    danger: { bg: "transparent", fg: "var(--warning)", border: "var(--warning)" },
  }[variant];

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || busy}
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
        height: compact ? 40 : "var(--button-height)",
        padding: compact ? "0 16px" : "0 22px",
        width: expand ? "100%" : undefined,
        borderRadius: "var(--r-pill)",
        background: palette.bg,
        color: palette.fg,
        border: `1px solid ${palette.border}`,
        font: "inherit",
        fontWeight: 600,
        fontSize: compact ? 14 : 15,
        cursor: disabled || busy ? "not-allowed" : "pointer",
        opacity: disabled ? 0.45 : 1,
        transition: "background var(--d-hover) var(--ease), border-color var(--d-hover) var(--ease)",
      }}
    >
      {busy ? <Spinner size={16} color={palette.fg} /> : glyph ? <Icon glyph={glyph} size={17} /> : null}
      {label}
    </button>
  );
}

/** The round icon button used in a toolbar. */
export function UtilityButton({
  glyph,
  onClick,
  title,
  active,
}: {
  glyph: Glyph;
  onClick?: (e: React.MouseEvent) => void;
  title?: string;
  active?: boolean;
}) {
  return (
    <Tappable
      onClick={onClick}
      title={title}
      radius={999}
      style={{
        width: "var(--utility-button)",
        height: "var(--utility-button)",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        border: `1px solid ${active ? "var(--accent)" : "var(--stroke)"}`,
        background: active ? "rgba(76,141,255,0.14)" : "transparent",
        color: active ? "var(--accent)" : "var(--fg-primary)",
      }}
    >
      <Icon glyph={glyph} size={18} />
    </Tappable>
  );
}

/* ------------------------------------------------------------------ field */

export function TextField({
  value,
  onChange,
  label,
  hint,
  type = "text",
  glyph,
  error,
  autoFocus,
  onEnter,
  dir,
}: {
  value: string;
  onChange: (v: string) => void;
  label?: string;
  hint?: string;
  type?: "text" | "password" | "email";
  glyph?: Glyph;
  error?: string;
  autoFocus?: boolean;
  onEnter?: () => void;
  dir?: "ltr" | "rtl";
}) {
  const [reveal, setReveal] = useState(false);
  const actual = type === "password" && reveal ? "text" : type;

  return (
    <div style={{ width: "100%" }}>
      {label && (
        <div className="t-label-md" style={{ color: "var(--fg-secondary)", marginBottom: 8 }}>
          {label}
        </div>
      )}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10,
          height: 52,
          padding: "0 14px",
          background: "var(--bg-sunken)",
          border: `1px solid ${error ? "var(--warning)" : "var(--stroke)"}`,
          borderRadius: "var(--r-field)",
          transition: "border-color var(--d-hover) var(--ease)",
        }}
      >
        {glyph && <Icon glyph={glyph} size={18} color="var(--fg-secondary)" />}
        <input
          dir={dir}
          type={actual}
          value={value}
          autoFocus={autoFocus}
          placeholder={hint}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && onEnter) onEnter();
          }}
          style={{
            flex: 1,
            minWidth: 0,
            background: "transparent",
            border: 0,
            outline: "none",
            color: "var(--fg-primary)",
            font: "inherit",
            fontSize: 15,
          }}
        />
        {type === "password" && (
          <Tappable onClick={() => setReveal((r) => !r)} radius={8} title={reveal ? "Hide" : "Show"}>
            <Icon glyph={reveal ? "eye-off" : "eye"} size={18} color="var(--fg-secondary)" />
          </Tappable>
        )}
      </div>
      {error && (
        <div className="t-body-sm" style={{ color: "var(--warning)", marginTop: 8 }}>
          {error}
        </div>
      )}
    </div>
  );
}

/* --------------------------------------------------------------- feedback */

export function Spinner({ size = 22, color = "var(--accent)" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className="ld-spin" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="var(--stroke)" strokeWidth="2.4" fill="none" />
      <path
        d="M21 12a9 9 0 0 0-9-9"
        stroke={color}
        strokeWidth="2.4"
        fill="none"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function EmptyState({
  glyph = "folder",
  title,
  message,
  actionLabel,
  onAction,
}: {
  glyph?: Glyph;
  title: string;
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <div
      className="ld-enter"
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        textAlign: "center",
        padding: "56px 24px",
        gap: 6,
      }}
    >
      <div
        style={{
          width: 64,
          height: 64,
          borderRadius: "var(--r-tile)",
          border: "1px solid var(--stroke)",
          background: "var(--bg-elevated)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          marginBottom: 14,
        }}
      >
        <Icon glyph={glyph} size={26} color="var(--fg-secondary)" />
      </div>
      <div className="t-title-md">{title}</div>
      {message && (
        <div className="t-body-md" style={{ color: "var(--fg-secondary)", maxWidth: 380 }}>
          {message}
        </div>
      )}
      {actionLabel && onAction && (
        <div style={{ marginTop: 16 }}>
          <Button label={actionLabel} onClick={onAction} expand={false} compact />
        </div>
      )}
    </div>
  );
}

export function ErrorState({
  message,
  onRetry,
  title,
}: {
  message: string;
  onRetry?: () => void;
  title?: string;
}) {
  return (
    <EmptyState
      glyph="alert"
      title={title ?? "Something went wrong"}
      message={message}
      actionLabel={onRetry ? "Try again" : undefined}
      onAction={onRetry}
    />
  );
}

/** The shape of what is coming is known, so a skeleton reads as content
 *  arriving rather than as a wait. */
export function GridSkeleton({ columns = 4 }: { columns?: number }) {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(auto-fill, minmax(150px, 1fr))`,
        gap: 14,
        padding: 20,
      }}
    >
      {Array.from({ length: columns * 2 }).map((_, i) => (
        <div key={i}>
          <div className="ld-skeleton" style={{ aspectRatio: "1 / 1", borderRadius: "var(--r-tile)" }} />
          <div className="ld-skeleton" style={{ height: 12, borderRadius: 6, marginTop: 10, width: "70%" }} />
          <div className="ld-skeleton" style={{ height: 10, borderRadius: 6, marginTop: 6, width: "40%" }} />
        </div>
      ))}
    </div>
  );
}

export function ListSkeleton({ rows = 8 }: { rows?: number }) {
  return (
    <div style={{ padding: 20, display: "flex", flexDirection: "column", gap: 10 }}>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <div className="ld-skeleton" style={{ width: 40, height: 40, borderRadius: 10 }} />
          <div style={{ flex: 1 }}>
            <div className="ld-skeleton" style={{ height: 12, borderRadius: 6, width: "45%" }} />
            <div className="ld-skeleton" style={{ height: 10, borderRadius: 6, width: "20%", marginTop: 7 }} />
          </div>
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------------ toast */

type Toast = { id: number; message: string; tone: "info" | "success" | "error" };
const ToastCtx = createContext<(m: string, tone?: Toast["tone"]) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastHost({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const next = useRef(1);

  const show = useCallback((message: string, tone: Toast["tone"] = "info") => {
    const id = next.current++;
    setItems((list) => [...list, { id, message, tone }]);
    setTimeout(() => setItems((list) => list.filter((t) => t.id !== id)), 4000);
  }, []);

  return (
    <ToastCtx.Provider value={show}>
      {children}
      {/* from the top on a phone, where the bottom is where the navigation is */}
      <div
        style={{
          position: "fixed",
          insetInline: 0,
          top: 16,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 8,
          zIndex: 900,
          pointerEvents: "none",
        }}
      >
        {items.map((t) => (
          <div
            key={t.id}
            className="ld-enter t-body-md"
            style={{
              pointerEvents: "auto",
              maxWidth: "min(560px, calc(100vw - 32px))",
              padding: "12px 16px",
              borderRadius: "var(--r-pill)",
              background: "var(--bg-elevated)",
              border: `1px solid ${
                t.tone === "error" ? "var(--warning)" : t.tone === "success" ? "var(--accent)" : "var(--stroke)"
              }`,
              display: "flex",
              alignItems: "center",
              gap: 10,
            }}
          >
            <Icon
              glyph={t.tone === "error" ? "alert" : t.tone === "success" ? "check" : "info"}
              size={17}
              color={t.tone === "error" ? "var(--warning)" : t.tone === "success" ? "var(--accent)" : "var(--fg-secondary)"}
            />
            {t.message}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

/* ----------------------------------------------------------------- avatar */

/**
 * A person, drawn as a deterministic gradient plus their initials. The same
 * seed always produces the same face, so an avatar is recognisable across
 * devices without the server ever storing an image.
 *
 * The hash and the two hue offsets are the same as LdAvatar's, so a face here
 * matches the face the app draws for the same person. Changing either number
 * silently repaints everyone.
 */
export function Avatar({
  name,
  seed = "",
  size = 32,
  showBorder = false,
}: {
  name: string;
  seed?: string;
  size?: number;
  showBorder?: boolean;
}) {
  const hash = hashOf(seed || "localdrive");
  const hue = hash % 360;
  const second = (hue + 38) % 360;
  return (
    <span
      style={{
        width: size,
        height: size,
        flex: "none",
        borderRadius: 999,
        background: `linear-gradient(to bottom right, hsl(${hue} 52% 56%), hsl(${second} 58% 42%))`,
        border: showBorder ? "2px solid var(--bg-primary)" : undefined,
        color: "var(--fg-primary)",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: size * 0.36,
        fontWeight: 600,
        lineHeight: 1,
        letterSpacing: 0,
      }}
    >
      {initialsOf(name)}
    </span>
  );
}

function hashOf(value: string): number {
  let hash = 0;
  for (let i = 0; i < value.length; i++) hash = (hash * 31 + value.charCodeAt(i)) & 0x7fffffff;
  return hash;
}

export function initialsOf(name: string): string {
  const trimmed = (name ?? "").trim();
  if (!trimmed) return "?";
  const parts = trimmed.split(/\s+/).filter(Boolean);
  if (parts.length === 1) return [...parts[0]].slice(0, 2).join("").toUpperCase();
  return parts
    .slice(0, 2)
    .map((p) => [...p][0])
    .join("")
    .toUpperCase();
}

/* ------------------------------------------------------------------ sheet */

export function Sheet({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.55)",
        zIndex: 800,
        display: "flex",
        alignItems: "flex-end",
        justifyContent: "center",
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="ld-enter"
        style={{
          width: "min(520px, 100%)",
          background: "var(--bg-elevated)",
          border: "1px solid var(--stroke)",
          borderBottom: 0,
          borderRadius: "var(--r-sheet) var(--r-sheet) 0 0",
          padding: 20,
          maxHeight: "80vh",
          overflowY: "auto",
          marginBottom: "env(safe-area-inset-bottom)",
        }}
      >
        <div
          style={{
            width: 36,
            height: 4,
            borderRadius: 2,
            background: "var(--stroke)",
            margin: "0 auto 16px",
          }}
        />
        {title && (
          <div className="t-title-md" style={{ marginBottom: 14 }}>
            {title}
          </div>
        )}
        {children}
      </div>
    </div>
  );
}

/* ----------------------------------------------------------------- dialog */

export function Dialog({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.55)",
        zIndex: 850,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 16,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="ld-enter"
        style={{
          width: "min(420px, 100%)",
          background: "var(--bg-elevated)",
          border: "1px solid var(--stroke)",
          borderRadius: "var(--r-card)",
          padding: 24,
        }}
      >
        {title && (
          <div className="t-title-md" style={{ marginBottom: 16 }}>
            {title}
          </div>
        )}
        {children}
      </div>
    </div>
  );
}


/** A menu anchored to the pointer, which is what a right click opens on
 *  desktop and what the overflow button opens everywhere. */
export function Menu({
  open,
  x,
  y,
  onClose,
  items,
}: {
  open: boolean;
  x: number;
  y: number;
  onClose: () => void;
  items: { label: string; glyph?: Glyph; onClick: () => void; danger?: boolean }[];
}) {
  useEffect(() => {
    if (!open) return;
    const close = () => onClose();
    window.addEventListener("click", close);
    window.addEventListener("resize", close);
    return () => {
      window.removeEventListener("click", close);
      window.removeEventListener("resize", close);
    };
  }, [open, onClose]);

  if (!open) return null;
  const left = Math.min(x, (typeof window !== "undefined" ? window.innerWidth : 0) - 230);
  const top = Math.min(y, (typeof window !== "undefined" ? window.innerHeight : 0) - items.length * 44 - 24);

  return (
    <div
      className="ld-enter"
      onClick={(e) => e.stopPropagation()}
      style={{
        position: "fixed",
        left,
        top,
        zIndex: 850,
        minWidth: 210,
        background: "var(--bg-elevated)",
        border: "1px solid var(--stroke)",
        borderRadius: "var(--r-card)",
        padding: 6,
      }}
    >
      {items.map((item) => (
        <Tappable
          key={item.label}
          radius={10}
          onClick={() => {
            onClose();
            item.onClick();
          }}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            width: "100%",
            padding: "10px 12px",
            color: item.danger ? "var(--warning)" : "var(--fg-primary)",
          }}
        >
          {item.glyph && <Icon glyph={item.glyph} size={17} />}
          <span className="t-body-md">{item.label}</span>
        </Tappable>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------ measurement */

/** The device class, from the width, matching Breakpoints in the app. */
export function useDeviceClass() {
  const [width, setWidth] = useState(1280);
  useEffect(() => {
    const measure = () => setWidth(window.innerWidth);
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, []);
  return useMemo(
    () => ({
      width,
      isMobile: width <= 600,
      isTablet: width > 600 && width <= 1024,
      isDesktop: width > 1024,
    }),
    [width],
  );
}
