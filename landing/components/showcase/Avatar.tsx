import { AVATAR_TONES } from "./data";

/*
  A person, as the app draws them: a flat tone and no photograph.

  The server never has a picture to show, because nobody uploads one, so the
  app assigns a colour per account and that is the whole identity. Keeping the
  same rule here means the share sheet on this page looks like the share sheet
  in the product rather than like a mockup of it.
*/
export function Avatar({
  seed,
  className,
  size = 16,
}: {
  seed: string;
  className?: string;
  size?: number;
}) {
  return (
    <span
      className={`flex items-center justify-center rounded-full border-[1.5px] border-base text-[8px] font-bold text-base ${className ?? ""}`}
      style={{
        width: size,
        height: size,
        background: AVATAR_TONES[seed] ?? "var(--color-accent)",
      }}
      aria-hidden
    />
  );
}
