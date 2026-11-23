// The Chrome extension has its own version in chrome/popup/settings.js: make shared changes in both.

// Where the popup reads and saves the redirect target, in Safari: the native
// handler, which keeps it in the App Group the app shares.

async function loadRedirectBase() {
  const response = await browser.runtime.sendNativeMessage("application.id", { type: "redirectBase" });
  return response?.redirectBase;
}

async function saveRedirectBase(redirectBase) {
  await browser.runtime.sendNativeMessage("application.id", { type: "setRedirectBase", redirectBase });
  // Points the rules at the new target.
  await browser.runtime.sendMessage({ type: "redirectBase" });
}
