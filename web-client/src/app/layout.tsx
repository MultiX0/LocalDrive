import type { Metadata, Viewport } from "next";
import { Space_Grotesk, IBM_Plex_Sans_Arabic } from "next/font/google";
import "./globals.css";
import { SessionProvider } from "@/lib/session";
import { ToastHost } from "@/components/ui";

/*
  The same pairing the Flutter client uses.

  Space Grotesk was designed for Latin and has no Arabic glyphs, so Arabic is
  not this face with substituted letters: it is IBM Plex Sans Arabic, chosen to
  sit beside it. Both are loaded here and one css rule switches on lang.
*/
const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const plexArabic = IBM_Plex_Sans_Arabic({
  subsets: ["arabic"],
  weight: ["400", "600", "700"],
  variable: "--font-plex-arabic",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Local Drive",
  description: "Your own file server, on your own hardware.",
};

export const viewport: Viewport = {
  themeColor: "#141414",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" dir="ltr">
      <body className={`${spaceGrotesk.variable} ${plexArabic.variable}`}>
        <SessionProvider>
          <ToastHost>{children}</ToastHost>
        </SessionProvider>
      </body>
    </html>
  );
}
