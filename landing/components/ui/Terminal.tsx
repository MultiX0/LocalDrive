/*
  A terminal block.

  Prompts and comments are not selectable, so copying the block gives the
  commands and nothing else. Copying a "$" into your shell is a small thing to
  get wrong and an annoying one to notice.
*/

export type Line =
  | { kind: "command"; text: string }
  | { kind: "comment"; text: string }
  | { kind: "output"; text: string }
  | { kind: "blank" };

export function Terminal({
  title,
  lines,
  className,
}: {
  title?: string;
  lines: Line[];
  className?: string;
}) {
  return (
    <div
      className={`overflow-hidden rounded-card border border-stroke bg-sunken ${className ?? ""}`}
    >
      {title && (
        <div className="flex items-center gap-2 border-b border-stroke px-4 py-2.5">
          <span className="text-[11px] font-semibold uppercase tracking-[0.4px] text-fg-muted">
            {title}
          </span>
        </div>
      )}
      <pre className="overflow-x-auto p-4 text-[13px] leading-[1.75]">
        <code className="font-mono">
          {lines.map((line, index) => {
            if (line.kind === "blank") return <div key={index}>&nbsp;</div>;

            if (line.kind === "comment") {
              return (
                <div key={index} className="select-none text-fg-muted">
                  # {line.text}
                </div>
              );
            }

            if (line.kind === "output") {
              return (
                <div key={index} className="text-fg-secondary">
                  {line.text}
                </div>
              );
            }

            return (
              <div key={index}>
                <span className="select-none text-accent">$ </span>
                <span className="text-fg">{line.text}</span>
              </div>
            );
          })}
        </code>
      </pre>
    </div>
  );
}
