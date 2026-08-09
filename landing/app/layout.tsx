import type { Metadata, Viewport } from "next";
import { IBM_Plex_Sans_Arabic, Space_Grotesk } from "next/font/google";

import { Footer } from "@/components/Footer";
import { Nav } from "@/components/Nav";
import { site } from "@/lib/site";

import "./globals.css";

/*
  The same two typefaces the app uses, for the same reason. Space Grotesk has
  no Arabic glyphs, and IBM Plex Sans Arabic has the same engineered geometric
  character, so the pair reads as deliberate rather than as a fallback.

  Only the three weights the design system actually uses are loaded.
*/
const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const plexArabic = IBM_Plex_Sans_Arabic({
  subsets: ["arabic"],
  weight: ["400", "600", "700"],
  variable: "--font-plex-arabic",
  display: "swap",
});

/*
  The social card.

  One 1200 by 630 image, referenced absolutely. WhatsApp, Discord, Twitter and
  the rest each fetch it themselves and most of them will not follow a relative
  path, which is why `metadataBase` is set: it makes every og:image absolute
  without repeating the origin at each call site.

  It is a PNG rather than something generated per request. Several of these
  scrapers time out quickly and none of them retry, so a card that is a static
  file already on disk is a card that actually appears.
*/
const ogImage = {
  url: "/og.png",
  width: 1200,
  height: 630,
  alt: `${site.name}: ${site.tagline}`,
  type: "image/png",
};

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: `${site.name} | ${site.tagline}`,
    template: `%s | ${site.name}`,
  },
  description: site.description,
  applicationName: site.name,
  authors: [{ name: site.author.name, url: site.author.url }],
  creator: site.author.name,
  keywords: [
    "self hosted",
    "google drive alternative",
    "private cloud storage",
    "file server",
    "open source",
    "nextcloud alternative",
    "home server",
    "go",
    "flutter",
  ],
  alternates: { canonical: "/" },
  openGraph: {
    title: `${site.name} - ${site.tagline}`,
    description: site.description,
    url: site.url,
    siteName: site.name,
    type: "website",
    locale: "en",
    images: [ogImage],
  },
  twitter: {
    card: "summary_large_image",
    title: `${site.name} - ${site.tagline}`,
    description: site.description,
    images: [ogImage],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  icons: {
    icon: [
      { url: "/mark.svg", type: "image/svg+xml" },
      { url: "/favicon.png", sizes: "512x512", type: "image/png" },
    ],
    apple: "/favicon.png",
  },
};

/*
  Structured data, so a search engine understands this is software rather than
  a company page. Price is stated as zero: without an offer field, a search
  result can list this next to paid competitors with no indication that it
  costs nothing.
*/
const structuredData = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: site.name,
  description: site.description,
  applicationCategory: "https://schema.org/DeveloperApplication",
  operatingSystem: "Windows, macOS, Linux, Android, iOS, Web",
  license: "https://opensource.org/licenses/MIT",
  isAccessibleForFree: true,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  author: { "@type": "Person", name: site.author.name, url: site.author.url },
  url: site.url,
};

export const viewport: Viewport = {
  // the browser chrome matches the page rather than sitting as a pale strip
  // above a dark site, which is the same reason the desktop app draws its own
  // title bar
  themeColor: "#141414",
  colorScheme: "dark",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      className={`${spaceGrotesk.variable} ${plexArabic.variable}`}
      suppressHydrationWarning
    >
      <head>
        <script
          type="application/ld+json"
          // the object is ours, built above from constants, so there is
          // nothing here a visitor could have influenced
          dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
        />
      </head>
      <body className="min-h-dvh antialiased">
        {/* the first stop for a keyboard, before the whole nav */}
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-chip focus:bg-elevated focus:px-4 focus:py-2.5 focus:text-[14px] focus:font-semibold"
        >
          Skip to content
        </a>
        <Nav />
        <main id="main">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
