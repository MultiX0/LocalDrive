import { PEOPLE, TRANSFERS } from "./data";
import { Avatar } from "./Avatar";
import { FileIcon } from "./FileIcon";

/*
  Transfers.

  This screen exists on the site to show the one promise the documentation
  makes loudest: a transfer is never silent. Every row says what it is doing,
  and the failed one names its actual reason and offers a retry, rather than
  showing a generic error and leaving someone to guess.
*/

const STATE_LABEL: Record<string, { text: string; tone: string }> = {
  uploading: { text: "Uploading", tone: "var(--color-accent)" },
  queued: { text: "Queued", tone: "var(--color-fg-muted)" },
  done: { text: "Done", tone: "var(--color-file-sheet)" },
  failed: { text: "Failed", tone: "var(--color-warning)" },
};

export function TransfersDemo() {
  return (
    <div className="h-[300px] p-4 text-[11px]">
      <div className="flex items-baseline justify-between pb-3">
        <span className="text-[12px] font-semibold">Transfers</span>
        <span className="text-[10px] text-fg-muted">
          1 uploading, 1 queued, 1 needs attention
        </span>
      </div>

      <ul className="space-y-1.5">
        {TRANSFERS.map((transfer) => {
          const state = STATE_LABEL[transfer.state];
          return (
            <li
              key={transfer.name}
              className="flex items-center gap-3 rounded-tile border border-stroke bg-elevated px-3 py-2.5"
            >
              <FileIcon size={26} kind={transfer.kind} label={transfer.ext} />

              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <p className="truncate text-[10.5px] font-semibold">
                    {transfer.name}
                  </p>
                  <span
                    className="ml-auto shrink-0 text-[9.5px] font-semibold"
                    style={{ color: state.tone }}
                  >
                    {state.text}
                  </span>
                </div>

                {/* a bar only where there is progress to show. a full width
                    empty track on a queued item reads as stalled */}
                {transfer.state !== "queued" && (
                  <div className="mt-1.5 h-[3px] overflow-hidden rounded-pill bg-stroke">
                    <div
                      className="h-full rounded-pill"
                      style={{
                        width: `${transfer.progress * 100}%`,
                        background:
                          transfer.state === "failed"
                            ? "var(--color-warning)"
                            : "var(--color-accent)",
                      }}
                    />
                  </div>
                )}

                <p className="mt-1 text-[9.5px] text-fg-muted">
                  {transfer.detail}
                </p>
              </div>

              {transfer.state === "failed" && (
                <span className="shrink-0 rounded-pill border border-stroke px-2.5 py-1 text-[9.5px] font-semibold">
                  Retry
                </span>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}

/*
  The share sheet.

  Two things kept deliberately apart: giving a person access, and putting
  something on the open internet behind a link. Nothing in the people half is a
  text field, so nobody has to know a username, and anyone on the same network
  right now sorts to the top with a live mark.
*/
export function ShareDemo() {
  return (
    <div className="h-[300px] p-4 text-[11px]">
      <div className="pb-1">
        <p className="text-[12px] font-semibold">Share</p>
        <p className="text-[10px] text-fg-muted">Kitchen rebuild.docx</p>
      </div>

      <div className="mt-3 flex gap-1 rounded-pill border border-stroke p-1">
        <span className="flex-1 rounded-pill bg-accent px-3 py-1 text-center text-[10px] font-semibold">
          People
        </span>
        <span className="flex-1 px-3 py-1 text-center text-[10px] text-fg-secondary">
          Link
        </span>
      </div>

      <ul className="mt-3 space-y-1">
        {PEOPLE.map((person) => (
          <li
            key={person.name}
            className="flex items-center gap-2.5 rounded-tile px-2 py-2"
          >
            <div className="relative">
              <Avatar seed={person.seed} size={24} />
              {/* nearby is a live indicator, not a stored attribute */}
              {person.nearby && (
                <span className="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-base bg-file-sheet" />
              )}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[10.5px] font-semibold">{person.name}</p>
              {person.nearby && (
                <p className="text-[9px] text-file-sheet">On this network</p>
              )}
            </div>
            {person.role ? (
              <span className="rounded-pill border border-stroke px-2 py-0.5 text-[9px] text-fg-secondary">
                {person.role}
              </span>
            ) : (
              <span className="rounded-pill bg-elevated px-2 py-0.5 text-[9px] text-fg-secondary">
                Share
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
