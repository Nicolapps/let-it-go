// The Safari extension has its own version in extension/background.js: make shared changes in both.

// Mirrors rules.json as dynamic rules that point at the redirect target saved
// in the popup. With no app, the target lives in chrome.storage.sync instead of
// the App Group, and there is no setup checklist to report allowed origins to.

// Also what rules.json points at.
const DEFAULT_BASE = "http://go";

async function fetchRedirectBase() {
  try {
    const { redirectBase } = await chrome.storage.sync.get("redirectBase");
    return normalizeBase(redirectBase);
  } catch {
    return DEFAULT_BASE;
  }
}

// Same as in extension/background.js.
// "go.example.com/" → "https://go.example.com"; bare hostnames like "go" stay on http.
function normalizeBase(value) {
  const base = (value ?? "").trim().replace(/\/+$/, "");
  if (!base) return DEFAULT_BASE;
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(base)) return base;
  return (base.includes(".") ? "https://" : "http://") + base;
}

async function applyRules() {
  const base = await fetchRedirectBase();
  const staticRules = await (await fetch(chrome.runtime.getURL("rules.json"))).json();
  // Swap only the base, keeping each rule's own path (http://go/\1/\2…).
  const rules = staticRules.map((rule) => ({
    ...rule,
    // Outrank the static copy, which always points at http://go.
    priority: rule.priority + 1,
    action: { ...rule.action, redirect: { regexSubstitution: retarget(rule.action.redirect.regexSubstitution, base) } },
  }));

  const current = await chrome.declarativeNetRequest.getDynamicRules();
  const target = new Map(rules.map((rule) => [rule.id, rule.action.redirect.regexSubstitution]));
  if (
    current.length === rules.length &&
    current.every((rule) => rule.action.redirect?.regexSubstitution === target.get(rule.id))
  ) {
    return base;
  }

  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: current.map((rule) => rule.id),
    addRules: rules,
  });
  return base;
}

// "http://go/\1/\2" → "https://go.example.com/\1/\2". Backslashes in the base
// are escaped, since the substitution treats them as capture references.
function retarget(substitution, base) {
  return base.replace(/\\/g, "\\\\") + substitution.slice(DEFAULT_BASE.length);
}

// A save in the popup syncs twice (its message and storage.onChanged), so runs
// queue up: two at once would both remove the same old rules and add the same
// IDs, and Chrome rejects the second.
let syncing = Promise.resolve();
function syncRules() {
  syncing = syncing.catch(() => {}).then(applyRules);
  return syncing;
}

chrome.runtime.onInstalled.addListener(syncRules);
chrome.runtime.onStartup.addListener(syncRules);
// Saved in the popup, or synced from another computer.
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "sync" && "redirectBase" in changes) syncRules();
});

// fallback.js and the popup ask for the target, which also keeps the rules
// fresh. Chrome needs sendResponse here rather than a returned promise.
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "redirectBase") return;
  syncRules().then(sendResponse, () => sendResponse(DEFAULT_BASE));
  return true;
});
