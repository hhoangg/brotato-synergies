// Composite a clean title onto the real (agy-generated) Steam Workshop art for tato-Synergies.
// Reads the untouched art from thumbnail.agy.png, overlays a bottom scrim + "Co-op Synergies"
// title (crisp vector text, not AI-garbled), and writes thumbnail.png. Idempotent: always builds
// from the .agy.png source, so re-running never double-stamps the text.
//
//   bun run tools/make-thumbnail.ts                 # default title
//   bun run tools/make-thumbnail.ts "Co-op Synergies"
import sharp from "sharp";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "..");
const SRC = resolve(ROOT, "thumbnail.agy.png");   // clean art (backup of what agy produced)
const OUT = resolve(ROOT, "thumbnail.png");
const TITLE = process.argv[2] ?? "Co-op Synergies";

const SIZE = 1024;

// Bottom scrim (transparent → dark) so the title reads over any art, + the title with a dark outline.
const overlay = `<svg width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="scrim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0d0d12" stop-opacity="0"/>
      <stop offset="55%" stop-color="#0d0d12" stop-opacity="0.65"/>
      <stop offset="100%" stop-color="#0d0d12" stop-opacity="0.92"/>
    </linearGradient>
  </defs>
  <rect x="0" y="788" width="${SIZE}" height="${SIZE - 788}" fill="url(#scrim)"/>
  <text x="512" y="952" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="92"
        font-weight="700" fill="#f4ead0" stroke="#0d0d12" stroke-width="7" paint-order="stroke"
        style="paint-order:stroke">${TITLE}</text>
  <rect x="356" y="978" width="312" height="4" rx="2" fill="#d2bb43" fill-opacity="0.85"/>
</svg>`;

const art = await sharp(SRC).resize(SIZE, SIZE, { fit: "cover" }).png().toBuffer();
const ovl = await sharp(Buffer.from(overlay)).png().toBuffer();

// Steam Workshop preview images must be < 1 MB. The agy art is a flat cartoon, so a palette
// (indexed) PNG compresses it well under the cap while staying crisp.
await sharp(art)
  .composite([{ input: ovl, top: 0, left: 0 }])
  .png({ palette: true, quality: 90, compressionLevel: 9, effort: 10 })
  .toFile(OUT);

const { statSync } = await import("node:fs");
const kb = Math.round(statSync(OUT).size / 1024);
console.log(`Wrote ${OUT} (1024x1024, title: "${TITLE}", ${kb} KB — Steam preview cap is 1024 KB)`);
