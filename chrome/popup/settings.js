// Where the popup reads and saves the redirect target, in Chrome: there is no
// app to share it with, so it lives in chrome.storage.sync, which follows the
// user to their other computers. Replaces extension/popup/settings.js.

async function loadRedirectBase() {
  const { redirectBase } = await chrome.storage.sync.get("redirectBase");
  return redirectBase;
}

async function saveRedirectBase(redirectBase) {
  await chrome.storage.sync.set({ redirectBase });
  // Waits for the rules to point at the new target before confirming the save.
  await chrome.runtime.sendMessage({ type: "redirectBase" });
}
