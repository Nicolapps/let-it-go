// The shared content script, fallback.js, uses Safari's `browser` namespace;
// Chrome only has `chrome`, whose MV3 APIs return promises just the same.
globalThis.browser ??= chrome;
