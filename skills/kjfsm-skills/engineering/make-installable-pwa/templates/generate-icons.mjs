// `public/icons/*.png` を1つの図から起こす。再生成は `pnpm icons:generate`。
// sharp を使わないのは、同梱の libvips が LGPL-3.0 だから。
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

import { Resvg } from "@resvg/resvg-js";

const BRAND = "#171717";
const OUT = path.join(import.meta.dirname, "..", "public", "icons");

// lucide `<name>`(24x24)。
const GLYPH = `
    <path d="M12 5v14" />
    <path d="M5 12h14" />`;

/** `fraction` は 1 辺に対するグリフの占有率。残りが余白になる。 */
function icon({ size, fraction, radius }) {
  const glyph = size * fraction;
  const offset = (size - glyph) / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <rect width="${size}" height="${size}" rx="${radius}" fill="${BRAND}" />
  <g transform="translate(${offset} ${offset}) scale(${glyph / 24})"
     fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${GLYPH}
  </g>
</svg>`;
}

// 角丸を持つのは `purpose: "any"` だけ。maskable と apple-touch-icon は端末側が
// マスクを当てるので全面を塗り、グリフをセーフゾーン(中央 80% の円)の内側へ寄せる。
const icons = [
  ["icon-192.png", icon({ size: 192, fraction: 0.6, radius: 42 })],
  ["icon-512.png", icon({ size: 512, fraction: 0.6, radius: 112 })],
  ["icon-maskable-512.png", icon({ size: 512, fraction: 0.5, radius: 0 })],
  ["apple-touch-icon.png", icon({ size: 180, fraction: 0.6, radius: 0 })],
];

await mkdir(OUT, { recursive: true });
await Promise.all(
  icons.map(async ([name, source]) => {
    await writeFile(path.join(OUT, name), new Resvg(source).render().asPng());
    console.log(`wrote ${name}`);
  }),
);
