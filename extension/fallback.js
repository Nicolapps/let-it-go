// Catches the go/ searches that rules.json can't redirect, e.g. go/foo/bar,
// which arrives as q=go%2Ffoo%2Fbar and needs decoding first.

const GOLINK_PREFIX = "go";

// Every supported engine uses ?q= except Yahoo.
const QUERY_PARAMS = { "search.yahoo.com": "p" };

const param = QUERY_PARAMS[location.hostname] ?? "q";
const query = new URLSearchParams(location.search).get(param)?.trim();
const match = query && /^([a-z0-9-]+)\/(\S+)$/i.exec(query);

if (match && match[1].toLowerCase() === GOLINK_PREFIX) {
  browser.runtime.sendMessage({ type: "redirectBase" }).then((base) => {
    location.replace(`${base}/${match[2]}`);
  });
}
