// shared header for every non-landing page: eyebrow, title, one line of lead
// text. each page used to size its own heading differently before this.
export function PageHeader({
  eyebrow,
  title,
  lead,
  children,
}: {
  eyebrow: string;
  title: string;
  lead?: string;
  children?: React.ReactNode;
}) {
  return (
    <header className="pb-12 sm:pb-14">
      <span className="inline-flex items-center gap-2.5 text-[11px] font-semibold uppercase tracking-[1.1px] text-accent">
        <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-accent" />
        {eyebrow}
      </span>
      <h1 className="mt-4 text-[38px] font-bold leading-[1.1] tracking-[-0.025em] sm:text-[46px]">
        {title}
      </h1>
      {lead && (
        <p className="mt-5 max-w-2xl text-[17px] leading-[27px] text-fg-secondary">
          {lead}
        </p>
      )}
      {children}
    </header>
  );
}
