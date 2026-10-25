import type { NextConfig } from "next";

const desktop = process.env.SHOTLI_DESKTOP === "1";

const nextConfig: NextConfig = {
  ...(desktop
    ? {
        output: "export",
        images: { unoptimized: true },
      }
    : {}),
  cacheComponents: !desktop,
  partialPrefetching: !desktop,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
