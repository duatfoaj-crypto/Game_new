#!/usr/bin/env bash
# Capture desktop + mobile screenshots of the exact CAPTURE_URL into CAPTURE_DIR.
# Leaves the app running; capture output stays outside the source tree.
# Exit 75 = temporary navigation/browser infrastructure failure.
# Exit 1  = script or rendering defect.
set -euo pipefail
time -p cd "$(dirname "$0")"
/usr/bin/time -p pwd
/usr/bin/time -p test -n "${CAPTURE_URL:?Set CAPTURE_URL to the exact URL to capture.}"
/usr/bin/time -p test -n "${CAPTURE_DIR:?Set CAPTURE_DIR to the screenshot output directory.}"
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p test -f "$HOME/.local/share/omgithub-playwright/linux.json"
/usr/bin/time -p node -e '
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const runtime = path.join(process.env.HOME, ".local/share/omgithub-playwright");
const require2 = createRequire(path.join(runtime, "package.json"));
const { chromium } = require2("playwright");
const config = JSON.parse(fs.readFileSync(path.join(runtime, process.platform === "darwin" ? "metal.json" : "linux.json"), "utf8"));
if (process.platform === "linux") {
  process.env.DISPLAY = process.env.DISPLAY || (":" + fs.readFileSync(path.join(runtime, "display"), "utf8").trim());
}
const url = process.env.CAPTURE_URL;
const output = process.env.CAPTURE_DIR;
const transient = (msg) => { const e = new Error(msg); e.exitCode = 75; throw e; };
(async () => {
  let browser;
  try {
    try {
      browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 });
    } catch (e) { transient("browser launch failed: " + e.message); }
    for (const [name, width, height] of [["desktop", 1440, 900], ["mobile", 390, 844]]) {
      let page;
      try {
        page = await browser.newPage({ viewport: { width, height } });
      } catch (e) { transient("newPage failed (" + name + "): " + e.message); }
      page.setDefaultTimeout(30000);
      page.on("pageerror", (e) => console.error("pageerror:", e.message));
      let response;
      try {
        response = await page.goto(url, { waitUntil: "load", timeout: 45000 });
      } catch (e) { transient("navigation failed (" + name + "): " + e.message); }
      if (!response || !response.ok()) {
        const status = response ? response.status() : 0;
        console.error("HTTP " + status + " loading preview (" + name + ")");
        const code = (!response || [408, 429, 500, 502, 503, 504].includes(status)) ? 75 : 1;
        process.exitCode = code;
        await page.close().catch(() => {});
        if (code !== 75) { await browser.close().catch(() => {}); process.exit(code); }
        await browser.close().catch(() => {});
        process.exit(75);
      }
      try {
        await page.locator(process.env.CAPTURE_READY_SELECTOR || "body").waitFor({ state: "visible", timeout: 30000 });
        await page.waitForFunction(() => document.fonts.status === "loaded", { timeout: 30000 });
      } catch (e) {
        console.error("render wait failed (" + name + "): " + e.message);
        await page.close().catch(() => {});
        await browser.close().catch(() => {});
        process.exit(1);
      }
      await page.waitForTimeout(1000);
      const dest = path.join(output, "final-" + name + ".png");
      try {
        await page.screenshot({ path: dest, timeout: 30000 });
      } catch (e) {
        if (e.name === "TimeoutError" || !browser.isConnected()) transient("screenshot failed (" + name + "): " + e.message);
        console.error("screenshot failed (" + name + "): " + e.message);
        await page.close().catch(() => {});
        await browser.close().catch(() => {});
        process.exit(1);
      }
      const bytes = fs.statSync(dest).size;
      if (!bytes) {
        console.error("empty screenshot (" + name + "): " + dest);
        await page.close().catch(() => {});
        await browser.close().catch(() => {});
        process.exit(1);
      }
      console.log("captured " + name + ": " + dest + " (" + bytes + " bytes)");
      await page.close();
    }
  } catch (e) {
    console.error(e && e.stack ? e.stack : String(e));
    process.exitCode = (e && e.exitCode) || 1;
  } finally {
    try { await browser?.close(); } catch (e) { console.error("browser close failed: " + e.message); process.exitCode = process.exitCode || 75; }
  }
})();
'
