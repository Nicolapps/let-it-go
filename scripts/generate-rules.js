#!/usr/bin/env node
// Writes extension/rules.json: one rule per search engine and go/ link depth.
//
// Redirect rules can't decode the query, so go/foo/bar arrives as
// q=go%2Ffoo%2Fbar and a single capture would stop at the second %2F. Instead,
// each depth gets its own rule that matches the %2F separators and puts real
// slashes back in the target. Deeper links and other encoded characters are
// left to fallback.js.
//
// Run with --check to fail instead of writing when rules.json is stale.

const fs = require("fs");
const path = require("path");

const MAX_SEGMENTS = 5;

const ENGINES = [
  { url: "https://www\\.google\\.com/search", param: "q" },
  { url: "https://www\\.bing\\.com/search", param: "q" },
  { url: "https://duckduckgo\\.com/", param: "q" },
  { url: "https://search\\.yahoo\\.com/search", param: "p" },
  { url: "https://www\\.ecosia\\.org/search", param: "q" },
];

const SEGMENT = "([^&+%#]+)";

const rules = [];
for (const engine of ENGINES) {
  for (let depth = 1; depth <= MAX_SEGMENTS; depth++) {
    const segments = Array(depth).fill(SEGMENT).join("%2F");
    const target = Array.from({ length: depth }, (_, i) => `\\${i + 1}`).join("/");
    rules.push({
      id: rules.length + 1,
      priority: 1,
      action: { type: "redirect", redirect: { regexSubstitution: `http://go/${target}` } },
      condition: {
        regexFilter: `^${engine.url}.*[?&]${engine.param}=go%2F${segments}(&.*)?$`,
        resourceTypes: ["main_frame"],
      },
    });
  }
}

const file = path.join(__dirname, "..", "extension", "rules.json");
const json = JSON.stringify(rules, null, 2) + "\n";

if (process.argv.includes("--check")) {
  if (fs.readFileSync(file, "utf8") !== json) {
    console.error("extension/rules.json is out of date; run `just rules`.");
    process.exit(1);
  }
} else {
  fs.writeFileSync(file, json);
}
