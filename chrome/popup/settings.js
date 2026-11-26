// The Safari extension has its own version in extension/popup/settings.js: make shared changes in both.

// Where the popup reads and saves the redirect target, in Chrome: there is no
// app to share it with, so it lives in chrome.storage.local, in this browser
// profile only, as PRIVACY.md promises.

async function loadRedirectBase() {
  const { redirectBase } = await chrome.storage.local.get("redirectBase");
  return redirectBase;
}

async function saveRedirectBase(redirectBase) {
  await chrome.storage.local.set({ redirectBase });
  // Waits for the rules to point at the new target before confirming the save.
  await chrome.runtime.sendMessage({ type: "redirectBase" });
}
