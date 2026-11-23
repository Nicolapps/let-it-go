# Chrome Web Store listing

What to paste into the Chrome Web Store developer dashboard. The images are in
`images/`; rebuild them with `just store-images` after editing `store.html`.

## Store listing

**Summary** (from the manifest's description, 132 characters at most)

> Opens go/ links instead of searching for them.

**Description**

> Typing go/standup into Chrome's address bar sends it to your search engine. Let It Go catches those searches and opens http://go/standup instead, or the same link on your own go-link server.
>
> • Works on Google, Bing, DuckDuckGo, Yahoo and Ecosia.
> • Keeps the whole link: go/docs/onboarding and go/q?id=42 open just like go/docs.
> • Bring your own server: links go to http://go by default, and you can point them anywhere, such as go.example.com, from the toolbar button.
> • Private: no analytics and no accounts. Searches that aren't go/ links are left alone, and your setting stays in your browser.
>
> Let It Go is open source: https://github.com/Nicolapps/let-it-go

**Category:** Productivity (Workflow & Planning)
**Language:** English

**Graphic assets**

| Field | File |
| --- | --- |
| Store icon (128×128) | from the zip (`icons/icon-128.png`) |
| Screenshots (1280×800) | `images/screenshot-1-hero.png` … `screenshot-4-engines.png`, in order |
| Small promo tile (440×280) | `images/promo-small-440x280.png` |
| Marquee promo tile (1400×560) | `images/promo-marquee-1400x560.png` |

**Homepage URL:** https://github.com/Nicolapps/let-it-go
**Support URL:** https://github.com/Nicolapps/let-it-go/issues

## Privacy practices

**Single purpose**

> Opens go/ links typed into the address bar, which Chrome sends to a search engine, at the go-link server the user chooses.

**Permission justifications**

- **declarativeNetRequestWithHostAccess:** Redirects searches for go/ links on the supported search engines to the user's go-link server before the search page loads. The rules match only go/ searches; other searches are left alone.
- **storage:** Saves the go-link server address the user sets in the popup, locally in their browser profile.
- **Host permissions (www.google.com, www.bing.com, duckduckgo.com, search.yahoo.com, www.ecosia.org):** Needed for the redirect rules to act on these search engines' result pages, and for a content script there that handles go/ links the rules can't match, such as go/foo?x=1. The script reads only the search query in the page's URL.

**Remote code:** No, I am not using remote code.

**Data usage:** tick none of the data types; the extension collects nothing. Then certify all three statements (no selling, no unrelated use, no creditworthiness use).

**Privacy policy URL:** https://github.com/Nicolapps/let-it-go/blob/main/PRIVACY.md

## Distribution

Public, all regions.
