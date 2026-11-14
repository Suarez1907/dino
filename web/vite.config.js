import { defineConfig } from "vite";
import path from "node:path";

export default defineConfig({
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
