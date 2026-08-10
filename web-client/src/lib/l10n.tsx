"use client";

import { useSession } from "./session";
import { setFormatLocale } from "./format";
import { strings, type Locale, type Strings } from "./l10n.generated";

/**
 * The strings, in the reader's language.
 *
 * Both clients read the same arb files: localdrive/lib/l10n is the source and
 * l10n.generated.ts is built from it, so a string changed for the app is
 * changed here too and the Arabic cannot silently fall behind the English.
 *
 * Usage mirrors the Flutter side, where every screen starts with
 * `final l10n = L10n.of(context)`:
 *
 *   const t = useL10n();
 *   t.connectTitle                       // a plain string
 *   t.signInBody({ serverName: host })   // one with a placeholder
 */
export function useL10n(): Strings {
  const { locale } = useSession();
  // set during render rather than in an effect: a date formatted in this same
  // pass has to already be in the right language
  setFormatLocale(locale);
  return strings[locale] ?? strings.en;
}

/** For the few places outside a component tree. */
export function stringsFor(locale: Locale): Strings {
  return strings[locale] ?? strings.en;
}

export type { Locale, Strings };
