import path from "node:path";

import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /*
    The documentation lives at ../docs, outside this project, and is read from
    there at build time rather than copied in. That keeps one source of truth:
    editing a page in docs/ updates the site, and the site can never show
    something the repository does not actually say.

    Next has to be told the workspace reaches above the app directory, or the
    build traces only landing/ and the docs are missing at runtime.
  */
  outputFileTracingRoot: path.join(import.meta.dirname, ".."),

  outputFileTracingIncludes: {
    "/docs/**": ["../docs/**/*.mdx"],
    "/license": ["../LICENSE"],
  },

  experimental: {
    // gray-matter and the mdx toolchain are server only. keeping them out of
    // the client bundle is the difference between a 40kb page and a 400kb one
    optimizePackageImports: ["shiki"],
  },
};

export default nextConfig;
