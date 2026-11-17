// Renders the header loop once per store language into renders/<locale>.mp4.
// Usage (from store_screenshots/header-loop): node render-all.mjs [locale ...]
import { execFileSync } from "node:child_process";
import { COPY, GEAR_OF_24 } from "../scripts/creative-copy.mjs";

const locales = process.argv.length > 2 ? process.argv.slice(2) : Object.keys(COPY.header);
for (const locale of locales) {
  const variables = { headline: COPY.header[locale], ofMax: GEAR_OF_24[locale], trainer: "Smart Trainer" };
  execFileSync(
    "npx",
    ["--yes", "hyperframes@0.8.188", "render", "--fps", "30", "--quality", "delivery", "--strict-variables", "--variables", JSON.stringify(variables), "-o", `renders/${locale}.mp4`],
    { cwd: import.meta.dirname, stdio: "inherit" },
  );
}
