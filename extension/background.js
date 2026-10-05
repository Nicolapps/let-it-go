// Mirrors rules.json as dynamic rules that point at the redirect target chosen
// in the app, which the native handler reads from the shared App Group.

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
  const target = base.replace(/\\/g, "\\\\") + "/\\1";

  const current = await browser.declarativeNetRequest.getDynamicRules();
  if (current.length > 0 && current.every((rule) => rule.action.redirect?.regexSubstitution === target)) {
    return base;
  }

  const staticRules = await (await fetch(browser.runtime.getURL("rules.json"))).json();
  await browser.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: current.map((rule) => rule.id),
    addRules: staticRules.map((rule) => ({
      ...rule,
      // Outrank the static copy, which always points at http://go.
      priority: rule.priority + 1,
      action: { ...rule.action, redirect: { regexSubstitution: target } },
    })),
  });
  return base;
}

browser.runtime.onInstalled.addListener(syncRules);
browser.runtime.onStartup.addListener(syncRules);
// Coming back to Safari after changing the target in the app.
browser.windows.onFocusChanged.addListener(syncRules);

// fallback.js asks for the target before redirecting, which also keeps the
// rules fresh on every search.
browser.runtime.onMessage.addListener((message) => {
  if (message?.type === "redirectBase") return syncRules();
});
