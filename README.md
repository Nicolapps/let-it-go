<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Let It Go app icon">
</p>

<h1 align="center">Let It Go</h1>

<p align="center">A Safari extension that opens <code>go/</code> links instead of searching for them.</p>

Typing `go/foo` into Safari's address bar sends it to your search engine. Let It Go catches those searches and redirects them to `http://go/foo`, or to a go-link server of your choice.

It works with Google, Bing, DuckDuckGo, Yahoo and Ecosia, and requires macOS 15 or later.

## Setup

1. Run `just install` to build the app and copy it into `/Applications`.
2. Open Let It Go and follow the checklist: enable the extension in Safari Settings, then allow it on your search engine.
3. Optionally, change where `go/` links point to in the redirect field (`http://go` by default).

## How it works

- `extension/rules.json` redirects simple `go/name` searches with declarative network rules, before the search page loads.
- `extension/background.js` copies those rules so they point at the redirect target set in the app.
- `extension/fallback.js` handles the searches the rules can't match, such as `go/foo/bar`.

## Development

Requires Xcode and [just](https://github.com/casey/just).

```sh
just run          # build and launch the Debug app
just lint         # validate the extension's JSON, JavaScript and rule regexes
just try <url>    # show where a search URL would be redirected
```
