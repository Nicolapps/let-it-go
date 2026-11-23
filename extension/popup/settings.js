// Where the popup reads and saves the redirect target, in Safari: the native
// handler, which keeps it in the App Group the app shares. The Chrome build
// replaces this file with chrome/popup/settings.js.

async function loadRedirectBase() {
  const response = await browser.runtime.sendNativeMessage("application.id", { type: "redirectBase" });
  return response?.redirectBase;
}

async function saveRedirectBase(redirectBase) {
  await browser.runtime.sendNativeMessage("application.id", { type: "setRedirectBase", redirectBase });
  // Points the rules at the new target.
  await browser.runtime.sendMessage({ type: "redirectBase" });
}
