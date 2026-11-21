# CI and releases

All automation lives in `.github/workflows`.

| Workflow | Runs on | What it does |
| --- | --- | --- |
| `ci.yml` | pull requests, pushes to `main`, manual dispatch | `just lint` (the extension's JSON, JavaScript and rule regexes) and a Debug build of the app and extension. On `main` and manual runs, a `release` job then archives a signed, notarized Release build of `Let It Go.app` and publishes it as a GitHub release, but only after lint and build pass. |
| `workflow-lint.yml` | pull requests, pushes to `main` | Runs [actionlint](https://github.com/rhysd/actionlint) and [zizmor](https://docs.zizmor.sh) against the workflows themselves. |

The macOS jobs run on the `xcode-27` image, which is still a GitHub preview: the project is saved in the Xcode 27 format and does not open in Xcode 26. Move to `macos-27` once that image is generally available, and drop the label from `.github/actionlint.yaml`.

Dependabot (`.github/dependabot.yml`) keeps the SHA-pinned actions current with a weekly grouped PR.

## Releases

Every push to `main` produces one release:

- Build number: the commit count (`git rev-list --count HEAD`), written into `CURRENT_PROJECT_VERSION`. It only goes up, as App Store Connect requires, and `just build` and `just upload` use it too. The short commit hash goes into the app's Info.plist as `GitCommit`.
- Tag: `v<MARKETING_VERSION>-build.<build number>-<short hash>`, for example `v1.0.0-build.54-cdbfb5b`. Bump `MARKETING_VERSION` in Xcode to change the version part.
- Asset: `Let-It-Go-<version>-build.<n>.zip`, created with `ditto` so the bundle survives the round trip intact.
- Notes: a short header plus GitHub's auto-generated notes (merged PRs and commits since the previous tag).

Re-running a workflow reuses the same tag and replaces the asset instead of failing. Running the workflow manually from a branch other than `main` publishes a pre-release. Runs on `main` are queued rather than cancelled, so a burst of pushes always ends with a release for the newest commit.

### Signing and notarization

The release job always signs with Developer ID and notarizes, and fails if any of the secrets below is missing. There is no ad-hoc fallback: the app group ID in the Swift sources is hardcoded to the team, and Safari only loads unsigned extensions while *Allow unsigned extensions* is on in its developer settings. The app group entitlement uses `$(TeamIdentifierPrefix)`, so no provisioning profile is needed.

To set the secrets, run `just setup-signing` on your Mac once. It finds your *Developer ID Application* certificate (or explains how to create one, with Xcode or in the browser), walks you through exporting it with its private key, checks the `.p12` and your notarization credentials, and uploads the five secrets with the GitHub CLI. Nothing is uploaded until every check passes.

You need:

- A paid [Apple Developer Program](https://developer.apple.com/programs/enroll/) membership where you are the Account Holder, because only the Account Holder can create Developer ID certificates.
- A [Developer ID Application certificate](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) with its private key in your login keychain. The easiest way to create one is Xcode → Settings → Accounts → your team → Manage Certificates → + → Developer ID Application.
- An [app-specific password](https://support.apple.com/en-us/102654) for your Apple ID, created at [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific Passwords.
- The [GitHub CLI](https://cli.github.com), logged in: `brew install gh && gh auth login`.

If you prefer to add them by hand:

| Secret | Value |
| --- | --- |
| `MACOS_SIGNING_CERTIFICATE_P12` | A *Developer ID Application* certificate plus private key, exported from Keychain Access as `.p12` and base64-encoded (`base64 -i cert.p12 \| pbcopy`). |
| `MACOS_SIGNING_CERTIFICATE_PASSWORD` | The password chosen when exporting the `.p12`. |
| `APPLE_TEAM_ID` | Your Apple Developer team ID. Used as `DEVELOPMENT_TEAM` when signing and as the notary team. |
| `NOTARY_APPLE_ID` | The Apple ID used for `notarytool`. |
| `NOTARY_PASSWORD` | An [app-specific password](https://support.apple.com/en-us/102654) for that Apple ID. |

## Running the checks locally

```sh
just lint
just build
```
