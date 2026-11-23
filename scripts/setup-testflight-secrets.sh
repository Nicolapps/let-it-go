#!/usr/bin/env bash
#
# Uploads the repository secrets that .github/workflows/ci.yml needs to upload the iOS app to
# App Store Connect for TestFlight. Run this on your Mac from the repository root:
#
#     just setup-testflight
#
# It walks you through everything, with links. In short, you need:
#
#   1. A paid Apple Developer Program membership with its agreements accepted. Apple refuses
#      uploads (and notarization) while an updated agreement is waiting to be accepted:
#        https://developer.apple.com/account
#   2. The Let It Go app in App Store Connect, with iOS as one of its platforms
#      (bundle ID dev.ettlin.nicolas.letitgo, the same as the Mac app's):
#        https://appstoreconnect.apple.com/apps
#   3. An App Store Connect API team key with the Admin role, its .p8 file, its key ID and the
#      issuer ID. Admin, because Xcode uses it in CI to manage the distribution certificate and
#      the provisioning profiles:
#        https://appstoreconnect.apple.com/access/integrations/api
#   4. The GitHub CLI, logged in:  brew install gh && gh auth login   (https://cli.github.com)
#
# Nothing is written anywhere except GitHub Actions secrets for this repository. GitHub secrets
# can't be read back, so to reuse the same key in another repository, run its copy of this
# script too: the same .p8 file and IDs work.

# The curly quotes in the instructions are intentional (they are printed, not parsed).
# shellcheck disable=SC1111

set -euo pipefail

bold=$(tput bold 2>/dev/null || true)
dim=$(tput dim 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

say() { printf '%s\n' "$*"; }
step() { printf '\n%s%s%s\n' "$bold" "$*" "$reset"; }
note() { printf '%s%s%s\n' "$dim" "$*" "$reset"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# Asks a yes/no question; defaults to no.
ask() {
  local answer
  read -r -p "$1 [y/N] " answer
  case "$answer" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# Accepts paths pasted with quotes or with backslash-escaped spaces (as Finder drag & drop does).
clean_path() {
  local path="$1"
  path="${path%"${path##*[![:space:]]}"}"
  path="${path#\'}"; path="${path%\'}"
  path="${path#\"}"; path="${path%\"}"
  path="${path//\\ / }"
  path="${path/#\~/$HOME}"
  printf '%s' "$path"
}

[ "$(uname)" = "Darwin" ] || fail "Run this on your Mac: it checks the key with Xcode's notarytool."
command -v xcrun > /dev/null || fail "Xcode's command line tools are missing. Install Xcode, then run: xcode-select --install"

if ! command -v gh > /dev/null; then
  fail "GitHub CLI not found. Install it with: brew install gh   (or see https://cli.github.com)"
fi
gh auth status > /dev/null 2>&1 || fail "GitHub CLI is not logged in. Run: gh auth login"
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || fail "Run this from inside the Let It Go repository checkout."

say "This uploads 3 or 4 secrets to ${bold}$repo${reset} so that CI can upload the iOS app to TestFlight."
note "Stop at any time with Ctrl-C: nothing is uploaded before step 5."

# ---------------------------------------------------------------------------------------------
step "1/5  Developer agreements"
cat <<EOF
  App Store Connect refuses uploads while an updated agreement is waiting to be accepted, with
  “A required agreement is missing or has expired”. Only the team's Account Holder can accept it.

    1. Go to https://developer.apple.com/account and sign in. If a banner asks you to review an
       updated agreement, open it and accept it.
    2. Also check https://appstoreconnect.apple.com/business (“Agreements, Tax, and Banking”)
       for an agreement marked as pending. A free app only needs the Free Apps agreement,
       which comes with the membership.

EOF
if ask "Open developer.apple.com/account now?"; then open "https://developer.apple.com/account" || true; fi
read -r -p "Press Return once there's nothing left to accept. " _

# ---------------------------------------------------------------------------------------------
step "2/5  The app in App Store Connect, with iOS"
cat <<EOF
  The Mac and iOS apps share the bundle ID ${bold}dev.ettlin.nicolas.letitgo${reset}, so they are one
  app in App Store Connect with two platforms. Open https://appstoreconnect.apple.com/apps

  ${bold}If Let It Go is listed${reset} (with macOS only):
    1. Click it.
    2. In the sidebar on the left, under the platform's name, click “Add Platform” (or the +
       next to “macOS”), then choose iOS.

  ${bold}If it isn't listed yet:${reset}
    1. Click + at the top left → “New App”.
    2. Platforms: tick iOS (and macOS, to publish the Mac app there too).
    3. Name: Let It Go. Primary language: English. SKU: anything, e.g. letitgo.
    4. Bundle ID: choose dev.ettlin.nicolas.letitgo. If it isn't in the list, it hasn't been
       registered yet: build the app once in Xcode with your team selected (Xcode registers it),
       or add it at https://developer.apple.com/account/resources/identifiers/add/bundleId
    5. User access: Full Access. Click Create.

  You don't need to fill in the App Store page to use TestFlight.

  ${bold}Then register the App Group, once.${reset} CI can't do it with an API key: archive the iOS app
  on this Mac with your own Xcode account, either with Product › Archive in Xcode (scheme
  “Let It Go (iOS)”) or with: just upload-ios
  That enables App Groups on both App IDs and registers group.dev.ettlin.nicolas.letitgo.
  Without it, the build uploads but the extension can't read the redirect target.

EOF
if ask "Open App Store Connect now?"; then open "https://appstoreconnect.apple.com/apps" || true; fi
read -r -p "Press Return once Let It Go has iOS as a platform and you've archived it once. " _

# ---------------------------------------------------------------------------------------------
step "3/5  App Store Connect API key"
cat <<EOF
  CI signs and uploads with an API key rather than your Apple ID. To create one:

    1. Go to https://appstoreconnect.apple.com/access/integrations/api
       (Users and Access → Integrations → App Store Connect API).
    2. Choose the “Team Keys” tab, not “Individual Keys”.
       The first time, the Account Holder has to click “Request Access” and agree to the terms;
       access is granted right away.
    3. Click + (or “Generate API Key”). Name it e.g. “GitHub TestFlight” and set Access to
       ${bold}Admin${reset}. A lower role can upload, but can't let Xcode create the distribution
       certificate and the provisioning profiles that CI needs.
    4. Click “Download” next to the new key. ${bold}Apple lets you download it only once.${reset}
       The file is named AuthKey_<KEY ID>.p8, for example AuthKey_2X9R4HXF34.p8
    5. Note the two IDs on that page:
         • Key ID: the 10-character ID in the key's row (also in the file name).
         • Issuer ID: shown above the list of keys, like 69a6de8e-1a2b-47e3-e053-5b8c7c11a4d1
       Apple's guide: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api

EOF
if ask "Open the API keys page now?"; then open "https://appstoreconnect.apple.com/access/integrations/api" || true; fi
say
note "Tip: you can drag the .p8 file from the Finder into this window to paste its path."
read -r -p ".p8 path: " p8_path
p8_path=$(clean_path "$p8_path")
[ -f "$p8_path" ] || fail "No file at $p8_path"
grep -q 'BEGIN PRIVATE KEY' "$p8_path" \
  || fail "$p8_path isn't an App Store Connect API key: those start with “-----BEGIN PRIVATE KEY-----”."

# The downloaded file is named after its key ID, so offer that as the default.
suggested_key_id=$(basename "$p8_path" | sed -nE 's/^AuthKey_([A-Z0-9]{10})\.p8$/\1/p')
if [ -n "$suggested_key_id" ]; then
  read -r -p "Key ID [$suggested_key_id]: " key_id
  key_id="${key_id:-$suggested_key_id}"
else
  read -r -p "Key ID (10 letters and digits): " key_id
fi
[[ "$key_id" =~ ^[A-Z0-9]{10}$ ]] || fail "“${key_id}” doesn't look like a key ID: it's 10 capital letters and digits, e.g. 2X9R4HXF34."

read -r -p "Issuer ID: " issuer_id
issuer_id=$(printf '%s' "$issuer_id" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
[[ "$issuer_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] \
  || fail "“${issuer_id}” doesn't look like an issuer ID: it's a UUID, e.g. 69a6de8e-1a2b-47e3-e053-5b8c7c11a4d1."

say "Checking the key against Apple…"
if ! check_output=$(xcrun notarytool history --key "$p8_path" --key-id "$key_id" --issuer "$issuer_id" 2>&1); then
  printf '%s\n' "$check_output" >&2
  case "$check_output" in
    *agreement*)
      fail "An agreement is still waiting to be accepted: see step 1." ;;
    *401*|*nauthorized*|*nvalid*)
      fail "Apple didn't accept this key. Check that the key ID matches the .p8 file, that the issuer ID is the one shown above the Team Keys list, and that the key hasn't been revoked." ;;
    *)
      fail "Couldn't check the key (see Apple's message above)." ;;
  esac
fi
say "OK: Apple accepted the key."
note "This can't check the key's role: make sure it's Admin, or the upload fails in CI when Xcode"
note "tries to create the provisioning profiles."

# ---------------------------------------------------------------------------------------------
step "4/5  Team ID"
team_id=""
if gh secret list --repo "$repo" 2>/dev/null | grep -q '^APPLE_TEAM_ID[[:space:]]'; then
  say "APPLE_TEAM_ID is already set (by just setup-signing); keeping it."
else
  cat <<EOF
  Your Apple Developer team ID: 10 capital letters and digits, shown at
  https://developer.apple.com/account under “Membership details”.

EOF
  read -r -p "Team ID: " team_id
  [[ "$team_id" =~ ^[A-Z0-9]{10}$ ]] || fail "“${team_id}” doesn't look like a team ID: it's 10 capital letters and digits."
fi

# ---------------------------------------------------------------------------------------------
step "5/5  Uploading secrets to $repo"
base64 -i "$p8_path" | gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo "$repo"
gh secret set APP_STORE_CONNECT_KEY_ID --repo "$repo" --body "$key_id"
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$repo" --body "$issuer_id"
[ -z "$team_id" ] || gh secret set APPLE_TEAM_ID --repo "$repo" --body "$team_id"

say
say "Done. The next push to main uploads the iOS app to App Store Connect. To start one now:"
say "  gh workflow run CI --ref main"
say
say "A build appears in TestFlight once Apple has processed it, usually within half an hour"
say "(App Store Connect emails you). To install it on your iPhone or iPad:"
say "  1. In App Store Connect, open Let It Go → TestFlight → Internal Testing, click +, create"
say "     a group and add yourself (and anyone else on the team) as testers."
say "  2. Install the TestFlight app from the App Store, signed in with the same Apple ID."
say
say "The .p8 file is a private key for your whole team. Keep it somewhere safe (a password"
say "manager is a good place) or delete it, and revoke the key in App Store Connect if it leaks:"
say "  rm \"$p8_path\""
note "Apple won't let you download it again: for another repository, keep a copy or create a new key."
