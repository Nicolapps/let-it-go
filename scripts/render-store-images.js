#!/usr/bin/env node
// Renders the Chrome Web Store images from store/chrome/store.html into
// store/chrome/images: four 1280×800 screenshots, the 440×280 small promo
// tile and the 1400×560 marquee. Needs Playwright with Chromium
// (`npm install -g playwright && npx playwright install chromium`).

const path = require("path");
const { chromium } = require("playwright");

const SCENES = [
  { scene: "hero", file: "screenshot-1-hero.png", width: 1280, height: 800 },
  { scene: "redirect", file: "screenshot-2-redirect.png", width: 1280, height: 800 },
  { scene: "popup", file: "screenshot-3-popup.png", width: 1280, height: 800 },
  { scene: "engines", file: "screenshot-4-engines.png", width: 1280, height: 800 },
  { scene: "small", file: "promo-small-440x280.png", width: 440, height: 280 },
  { scene: "marquee", file: "promo-marquee-1400x560.png", width: 1400, height: 560 },
];

const dir = path.join(__dirname, "..", "store", "chrome");

(async () => {
  const browser = await chromium.launch({ args: ["--allow-file-access-from-files"] });
  for (const { scene, file, width, height } of SCENES) {
    // The store wants images at exactly these sizes, so no 2× rendering.
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    await page.goto(`file://${dir}/store.html?scene=${scene}`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(500); // The popup's iframe draws its snow on the next frame.
    await page.screenshot({ path: path.join(dir, "images", file) });
    await page.close();
    console.log(`store/chrome/images/${file}`);
  }
  await browser.close();
})();
