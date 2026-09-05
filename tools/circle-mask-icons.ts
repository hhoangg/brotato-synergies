#!/usr/bin/env bun
// Circular-mask skill icons: keep a centered circle (default = inscribed circle, i.e. r = size/2),
// make everything outside it fully transparent. Deterministic geometric cut from the image center —
// works no matter what background the generator produced (no chroma-key, no model-side alpha needed).
// Output is a 32-bit RGBA PNG.
//
// Usage (from repo root):
//   bun run tools/circle-mask-icons.ts <file-or-dir> [--radius N] [--out DIR] [--suffix S]
//
//   # in-place overwrite every PNG in the skills folder (256px → keeps centered r=128 circle):
//   bun run tools/circle-mask-icons.ts mods-unpacked/tato-Synergies/assets/skills
//
//   # shave a thin background ring at the circle edge by cutting a hair tighter:
//   bun run tools/circle-mask-icons.ts <dir> --radius 122
//
//   # write masked copies elsewhere instead of overwriting:
//   bun run tools/circle-mask-icons.ts <dir> --out /tmp/masked

import sharp from "sharp";
import { readdir, stat, mkdir, writeFile } from "node:fs/promises";
import { join, dirname, basename, extname } from "node:path";

const args = process.argv.slice(2);
const positional = args.filter((a) => !a.startsWith("--"));
const target = positional[0];
function flag(name: string): string | undefined {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
}
if (!target) {
  console.error("usage: bun run circle-mask-icons.ts <file-or-dir> [--radius N] [--out DIR] [--suffix S]");
  process.exit(1);
}
const radiusArg = flag("radius");
const radius = radiusArg ? Number(radiusArg) : undefined; // undefined → inscribed circle (min(w,h)/2)
const outDir = flag("out");
const suffix = flag("suffix") ?? "";

async function listPngs(p: string): Promise<string[]> {
  const s = await stat(p);
  if (s.isDirectory()) {
    return (await readdir(p))
      .filter((n) => n.toLowerCase().endsWith(".png"))
      .map((n) => join(p, n));
  }
  return [p];
}

async function maskOne(file: string): Promise<void> {
  const meta = await sharp(file).metadata();
  const w = meta.width ?? 0;
  const h = meta.height ?? 0;
  if (!w || !h) throw new Error(`no dimensions: ${file}`);
  const r = radius ?? Math.min(w, h) / 2;
  const mask = Buffer.from(
    `<svg width="${w}" height="${h}"><circle cx="${w / 2}" cy="${h / 2}" r="${r}" fill="#fff"/></svg>`,
  );

  // dest-in keeps the source pixels only where the mask is opaque → outside the circle becomes transparent.
  const buf = await sharp(file)
    .ensureAlpha()
    .composite([{ input: mask, blend: "dest-in" }])
    .png()
    .toBuffer();

  const out = outDir
    ? join(outDir, basename(file))
    : suffix
      ? join(dirname(file), basename(file, extname(file)) + suffix + ".png")
      : file; // in-place overwrite (we buffered first, so read/write of the same path is safe)

  if (outDir) await mkdir(outDir, { recursive: true });
  await writeFile(out, buf);
  console.log(`✓ ${file} → ${out}  (${w}x${h}, r=${r})`);
}

const files = await listPngs(target);
if (!files.length) {
  console.error("no .png found");
  process.exit(1);
}
for (const f of files) await maskOne(f);
console.log(`done: ${files.length} icon(s).`);
