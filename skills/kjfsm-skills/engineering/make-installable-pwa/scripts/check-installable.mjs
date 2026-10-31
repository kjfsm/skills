#!/usr/bin/env node
// 使い方: node check-installable.mjs <url>
// 対象リポジトリをカレントにして走らせる。Playwright はそこの node_modules から解決する。
import { mkdtemp, rm } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";

const target = process.argv[2];
if (!target) {
  console.error("usage: check-installable.mjs <url>");
  process.exit(2);
}

function loadChromium() {
  const require = createRequire(path.join(process.cwd(), "package.json"));
  for (const name of ["playwright", "@playwright/test", "playwright-core"]) {
    try {
      return require(name).chromium;
    } catch {}
  }
  console.error("Playwright が見つからない: 対象リポジトリで走らせるか、devDependency に入れる");
  process.exit(2);
}

const failures = [];

// ブラウザの文脈ではなく素の fetch で取る —— サインインしていない端末と同じく Cookie を持たない。
// redirect を追わないのは、締め出しの 302 を 200 の /signin と取り違えないため。
async function expectAsset(label, url, contentType) {
  const res = await fetch(url, { redirect: "manual" });
  const type = res.headers.get("content-type") ?? "";
  if (res.status !== 200) {
    const to = res.headers.get("location");
    failures.push(`${label}: ${url} が ${res.status}${to ? ` → ${to}` : ""}`);
  } else if (contentType && !type.startsWith(contentType)) {
    failures.push(`${label}: ${url} の content-type が ${type}(${contentType} であるべき)`);
  } else {
    console.log(`ok  ${label}: ${url}`);
  }
}

// 既定の headless shell では Page.getInstallabilityErrors が壊れた manifest にも空を返す。
// channel "chromium"(新しい headless)で、シークレットではない永続プロファイルとして開く
// —— 使い捨ての文脈では必ず in-incognito が出る。
const profile = await mkdtemp(path.join(tmpdir(), "check-installable-"));
const context = await loadChromium().launchPersistentContext(profile, { channel: "chromium" });
try {
  const page = context.pages()[0] ?? (await context.newPage());
  await page.goto(target, { waitUntil: "load" });
  const cdp = await page.context().newCDPSession(page);

  const links = await page.evaluate(() => ({
    manifest: document.querySelector('link[rel="manifest"]')?.href ?? null,
    touchIcon: document.querySelector('link[rel="apple-touch-icon"]')?.href ?? null,
  }));
  if (links.manifest) await expectAsset("manifest", links.manifest, "application/manifest+json");
  else failures.push('manifest: <link rel="manifest"> が無い');

  const manifest = await cdp.send("Page.getAppManifest");
  for (const error of manifest.errors) failures.push(`manifest: ${error.message}`);

  const { installabilityErrors } = await cdp.send("Page.getInstallabilityErrors");
  for (const { errorId, errorArguments } of installabilityErrors) {
    const args = errorArguments.map(({ name, value }) => `${name}=${value}`).join(" ");
    failures.push(`installability: ${errorId}${args ? ` (${args})` : ""}`);
  }

  if (manifest.url) {
    const icons = JSON.parse(manifest.data || "{}").icons ?? [];
    for (const { src, purpose = "any" } of icons) {
      await expectAsset(`icon(${purpose})`, new URL(src, manifest.url).href, "image/");
    }
  }

  if (links.touchIcon) await expectAsset("apple-touch-icon", links.touchIcon, "image/");
  else failures.push('apple-touch-icon: <link rel="apple-touch-icon"> が無い');
} finally {
  await context.close();
  await rm(profile, { recursive: true, force: true });
}

for (const failure of failures) console.log(`NG  ${failure}`);
console.log(failures.length === 0 ? "installable" : `${failures.length} 件の失敗`);
process.exit(failures.length === 0 ? 0 : 1);
