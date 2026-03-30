// esbuild configuration — bundles the browser-side TypeScript entry point
// into a single file served by the Express server.
import * as esbuild from "esbuild";
import { mkdirSync } from "fs";

mkdirSync("dist/public", { recursive: true });

await esbuild.build({
  entryPoints: ["src/client/app.ts"],
  bundle: true,
  outfile: "dist/public/bundle.js",
  platform: "browser",
  target: "es2020",
  format: "iife",
  minify: process.env.NODE_ENV === "production",
  sourcemap: process.env.NODE_ENV !== "production",
  // Tree-shake unused Firebase modules
  define: {
    "process.env.NODE_ENV": JSON.stringify(
      process.env.NODE_ENV ?? "production"
    ),
  },
});

console.log("Client bundle built → dist/public/bundle.js");

