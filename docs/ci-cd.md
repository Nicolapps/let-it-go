# CI and releases

All automation lives in `.github/workflows`.

| Workflow | Runs on | What it does |
| --- | --- | --- |
| `ci.yml` | pull requests, pushes to `main`, manual dispatch | `just lint` (the extension's JSON, JavaScript and rule regexes) and Debug builds of the Mac and iOS apps with their extensions (iOS for the simulator, unsigned). On `main` and manual runs, once lint and build pass, a `release` job archives a signed, notarized Release build of the Mac app and publishes it as a GitHub release, and a `testflight` job uploads a Release build of the iOS app to App Store Connect for TestFlight. |
| `workflow-lint.yml` | pull requests, pushes to `main` | Runs [actionlint](https://github.com/rhysd/actionlint) and [zizmor](https://docs.zizmor.sh) against the workflows themselves. |

The macOS jobs run on the `xcode-27` image, which is still a GitHub preview: the project is saved in the Xcode 27 format and does not open in Xcode 26. Move to `macos-27` once that image is generally available, and drop the label from `.github/actionlint.yaml`.

Dependabot (`.github/dependabot.yml`) keeps the SHA-pinned actions current with a weekly grouped PR.

## Releases

Every push to `main` produces one GitHub release of the Mac app, and one TestFlight build of the iOS app (see [TestFlight](#testflight) below). The two jobs are independent: one failing doesn't stop the other.

The Mac release:

- Build number: the commit count (`git rev-list --count HEAD`), written into `CURRENT_PROJECT_VERSION`. It only goes up, as App Store Connect requires, and `just build` and `just upload` use it too. The short commit hash goes into the app's Info.plist as `GitCommit`.
- Tag: `v<MARKETING_VERSION>-build.<build number>-<short hash>`, for example `v1.0.0-build.54-cdbfb5b`. Bump `MARKETING_VERSION` in Xcode to change the version part.
- Asset: `Let-It-Go-<version>-build.<n>.zip`, created with `ditto` so the bundle survives the round trip intact.
- Notes: a short header plus GitHub's auto-generated notes (merged PRs and commits since the previous tag).

Re-running a workflow reuses the same tag and replaces the asset instead of failing. Running the workflow manually from a branch other than `main` publishes a pre-release. Runs on `main` are queued rather than cancelled, so a burst of pushes always ends with a release for the newest commit.

## TestFlight

The `testflight` job archives the *Let It Go (iOS)* scheme and uploads it to App Store Connect. Once Apple has processed it, usually within a few minutes to an hour, it is available to the app's internal testers in TestFlight. Testing with external testers, and submitting to the App Store, stay manual steps in App Store Connect.

- Build number: `<run number>.<run attempt>`, for example `42.1`. App Store Connect rejects a build number it has already seen, so a re-run uploads as `42.2` rather than failing. The version is the same `MARKETING_VERSION` as the Mac app.
- Signing: automatic, with the App Store Connect API key below. Xcode uses the team's cloud-managed distribution certificate and creates or updates the App Store provisioning profiles itself, including the `group.dev.ettlin.nicolas.letitgo` app group, so no certificate or profile is kept in the secrets.
- Export compliance: the app declares `ITSAppUsesNonExemptEncryption = NO`, so builds don't wait on the encryption question.

The job fails if any of its secrets is missing. Before the first upload:

1. In App Store Connect, add iOS to the Let It Go app (bundle ID `dev.ettlin.nicolas.letitgo`), or create the app if it doesn't exist yet. The Mac and iOS apps share their bundle IDs, so they are one app with two platforms.
2. Create an API key with the Admin role under *Users and Access › Integrations › App Store Connect API › Team Keys*, and download its `.p8` file.
3. Run `just setup-testflight` on your Mac. It checks the key against Apple and uploads the secrets with the GitHub CLI.

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_P8` | The API key's `.p8` file, base64-encoded (`base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy`). |
| `APP_STORE_CONNECT_KEY_ID` | The key's ID. |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer ID shown above the list of keys. |
| `APPLE_TEAM_ID` | Shared with the Mac release (see below). |

## Mac signing and notarization

The release job always signs with Developer ID and notarizes, and fails if any of the secrets below is missing. There is no ad-hoc fallback: the app group ID in the Swift sources is hardcoded to the team, and Safari only loads unsigned extensions while *Allow unsigned extensions* is on in its developer settings. The app group entitlement uses `$(TeamIdentifierPrefix)`, so no provisioning profile is needed.

To set the secrets, run `just setup-signing` on your Mac once. It finds your *Developer ID Application* certificate, walks you through exporting it, checks your notarization credentials against Apple, and uploads the five secrets with the GitHub CLI.

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
just build-ios
```

Neither builds anything for release: the signed Mac release and the TestFlight upload only run in CI.
