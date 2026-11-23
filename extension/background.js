// The Chrome extension has its own version in chrome/background.js: make shared changes in both.

// Mirrors rules.json as dynamic rules that point at the redirect target chosen
// in the app, which the native handler reads from the shared App Group.

// Also what rules.json points at.
const DEFAULT_BASE = "http://go";

async function fetchRedirectBase() {
  try {
    const response = await browser.runtime.sendNativeMessage("application.id", { type: "redirectBase" });
    return normalizeBase(response?.redirectBase);
  } catch {
    return DEFAULT_BASE;
  }
}

// "go.example.com/" → "https://go.example.com"; bare hostnames like "go" stay on http.
function normalizeBase(value) {
  const base = (value ?? "").trim().replace(/\/+$/, "");
  if (!base) return DEFAULT_BASE;
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(base)) return base;
  return (base.includes(".") ? "https://" : "http://") + base;
}

async function syncRules() {
  const base = await fetchRedirectBase();
  const staticRules = await (await fetch(browser.runtime.getURL("rules.json"))).json();
  // Swap only the base, keeping each rule's own path (http://go/\1/\2…).
  const rules = staticRules.map((rule) => ({
    ...rule,
    // Outrank the static copy, which always points at http://go.
    priority: rule.priority + 1,
    action: { ...rule.action, redirect: { regexSubstitution: retarget(rule.action.redirect.regexSubstitution, base) } },
  }));

  const current = await browser.declarativeNetRequest.getDynamicRules();
  const target = new Map(rules.map((rule) => [rule.id, rule.action.redirect.regexSubstitution]));
  if (
    current.length === rules.length &&
    current.every((rule) => rule.action.redirect?.regexSubstitution === target.get(rule.id))
  ) {
    return base;
  }

  await browser.declarativeNetRequest.updateDynamicRules({
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

// Tells the app which search engines the user has allowed in Safari Settings ›
// Extensions › Edit Websites…, for its setup checklist.
async function reportAllowedOrigins() {
  const origins = [];
  for (const origin of browser.runtime.getManifest().host_permissions) {
    if (await browser.permissions.contains({ origins: [origin] })) origins.push(origin);
  }
  console.log("Allowed origins:", origins);
  await browser.runtime.sendNativeMessage("application.id", { type: "allowedOrigins", origins });
}

browser.runtime.onInstalled.addListener(syncRules);
browser.runtime.onStartup.addListener(syncRules);
// Coming back to Safari after changing the target in the app. Safari on iOS
// may not have windows events, and fallback.js keeps the rules fresh anyway.
browser.windows?.onFocusChanged?.addListener(syncRules);

reportAllowedOrigins();
browser.permissions.onAdded.addListener(reportAllowedOrigins);
browser.permissions.onRemoved.addListener(reportAllowedOrigins);
browser.windows?.onFocusChanged?.addListener(reportAllowedOrigins);

// fallback.js asks for the target before redirecting, which also keeps the
// rules fresh on every search.
browser.runtime.onMessage.addListener((message) => {
  if (message?.type === "redirectBase") return syncRules();
});
