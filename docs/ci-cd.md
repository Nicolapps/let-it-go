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

- Version and build number: the same as the Mac release, `MARKETING_VERSION` and the commit count, with the short hash in the Info.plist as `GitCommit`. App Store Connect refuses a build number it has already seen, so re-running the job for a commit it has already uploaded fails at the upload; there's nothing to redo in that case.
- Export: `scripts/ExportOptions.plist`, the same file `just upload` and `just upload-ios` use.
- Signing: the archive is built unsigned, because xcodebuild can't use an API key to sign at archive time (Apple refuses it with *Authentication failed*). The job then signs it locally, with no certificate, only to attach the app's and the extension's entitlements, so the `group.dev.ettlin.nicolas.letitgo` App Group survives. The export signs for real with the App Store Connect API key below: Xcode uses the team's cloud-managed distribution certificate and creates or updates the App Store provisioning profiles itself, so no certificate or profile is kept in the secrets.
- Export compliance: the app declares `ITSAppUsesNonExemptEncryption = NO`, so builds don't wait on the encryption question.

### Setting it up

The job fails if any of its secrets is missing, so do this once before merging the job into `main`. `just setup-testflight` walks you through all of it on your Mac, with links, checks the key against Apple and uploads the secrets with the GitHub CLI. The steps, in short:

1. **Accept Apple's agreements.** App Store Connect refuses uploads, and the notary service refuses the Mac release, with *A required agreement is missing or has expired* while an updated agreement is waiting. The team's Account Holder accepts it at [developer.apple.com/account](https://developer.apple.com/account) (a banner appears when one is pending) and, if anything is marked pending, under [Agreements, Tax, and Banking](https://appstoreconnect.apple.com/business).
2. **Add iOS to the app in App Store Connect.** The Mac and iOS apps share the bundle ID `dev.ettlin.nicolas.letitgo`, so they are one app with two platforms. In [Apps](https://appstoreconnect.apple.com/apps), open Let It Go and choose *Add Platform* › iOS in the sidebar. If the app doesn't exist yet, create it with + › *New App*, tick iOS (and macOS), and pick that bundle ID. If the bundle ID isn't offered, build the app once in Xcode with your team selected, which registers it, or [register it by hand](https://developer.apple.com/account/resources/identifiers/add/bundleId). The App Store page doesn't need to be filled in for TestFlight.

   **Then register the App Group, once:** archive the iOS app on your Mac with your own Xcode account, for example with `just upload-ios`, or with *Product › Archive* in Xcode with the *Let It Go (iOS)* scheme. That enables App Groups on both App IDs and registers `group.dev.ettlin.nicolas.letitgo`, which the API key can't do. Without it, uploads go through but the App Group is missing from the build, so the extension can't read the redirect target set in the app.
3. **Create an App Store Connect API key.** Under [Users and Access › Integrations › App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api), choose *Team Keys* (the first time, the Account Holder clicks *Request Access*), then + with the **Admin** role. A lower role can upload but can't let Xcode create the distribution certificate and provisioning profiles. Download the `.p8` file right away: Apple only lets you download it once. Note the key ID (10 characters, also in the file name `AuthKey_<KEY ID>.p8`) and the issuer ID (a UUID shown above the list).
4. **Run `just setup-testflight`.** It reuses `APPLE_TEAM_ID` if `just setup-signing` already set it.

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_P8` | The API key's `.p8` file, base64-encoded (`base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy`). |
| `APP_STORE_CONNECT_KEY_ID` | The key's ID, for example `2X9R4HXF34`. |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer ID shown above the list of team keys. |
| `APPLE_TEAM_ID` | Shared with the Mac release (see below). |

To start an upload without pushing, run `gh workflow run CI --ref main`. To upload a build from your Mac instead, with your own Xcode account, run `just upload-ios`.

### Installing a TestFlight build

App Store Connect emails you once a build has been processed. In Let It Go › TestFlight › *Internal Testing*, create a group with + and add yourself and anyone else on the team. Testers install the build with the [TestFlight app](https://apps.apple.com/app/testflight/id899247664), signed in with the same Apple ID. Builds for testers outside the team need Apple's beta review first, under *External Testing*.

### When the upload fails

- *A required agreement is missing or has expired*: an agreement is waiting to be accepted (step 1). Accept it, then re-run the failed job.
- *Authentication failed: Make sure a bearer token was provided* during the archive, followed by *No profiles for 'dev.ettlin.nicolas.letitgo' were found*: something is signing at archive time with the API key, which Apple refuses. The archive step must keep `CODE_SIGNING_ALLOWED=NO`.
- A certificate or profile error during the export: the API key isn't Admin. Create a new Admin key and run `just setup-testflight` again.
- The *Add entitlements* step fails: the archive's paths changed (target or product names). Update the paths in that step.
- *No suitable application records were found*: iOS isn't a platform of the app in App Store Connect yet (step 2).
- *The bundle version must be higher than the previously uploaded version*: this commit was already uploaded, usually by a re-run. There's nothing to redo.

## Mac signing and notarization

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
just build-ios
```

Neither builds anything for release: the signed Mac release and the TestFlight upload only run in CI.
