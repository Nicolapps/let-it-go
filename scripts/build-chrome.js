#!/usr/bin/env node
// Assembles the Chrome extension in build/chrome: the shared web extension in
// extension/ (rules, fallback, popup, icons), with the Chrome-only files in
// chrome/ laid over it. Load build/chrome as an unpacked extension, or zip it
// for the Chrome Web Store (`just package-chrome`).
//
// Safari's manifest and background script, which talk to the app through
// native messaging, are left out: chrome/ has its own.

const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const out = path.join(root, "build", "chrome");

const SHARED = ["rules.json", "fallback.js", "icons", "popup"];

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
for (const entry of SHARED) {
  fs.cpSync(path.join(root, "extension", entry), path.join(out, entry), { recursive: true });
}
fs.cpSync(path.join(root, "chrome"), out, { recursive: true });

console.log(`Built ${path.relative(root, out)}`);
