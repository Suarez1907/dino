import { defineConfig } from "vite";
import path from "node:path";

export default defineConfig({
  assetsInclude: ["**/*.hdr"],
  // GitHub Pages project sites are served under /<repo>/.
  // CI sets BASE_PATH (this repo: /dino/). Local dev and preview stay at /.
  base: process.env.BASE_PATH || "/",
  resolve: {
    alias: {
      "@shared": path.resolve(__dirname, "../shared/data"),
    },
  },
  server: {
    host: "0.0.0.0",
    port: 47321,
    fs: { allow: [path.resolve(__dirname, "..")] },
  },
  preview: { host: "0.0.0.0", port: 47321 },
});
