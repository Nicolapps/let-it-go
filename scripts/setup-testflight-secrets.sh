#!/usr/bin/env bash
#
# Uploads the repository secrets that .github/workflows/ci.yml needs to upload the iOS app to
# App Store Connect for TestFlight. Run this on your Mac from the repository root:
#
#     just setup-testflight
#
# Requirements:
#   - The GitHub CLI, logged in:  brew install gh && gh auth login
#   - An App Store Connect API key with the Admin role, so Xcode can use the team's cloud-managed
#     distribution certificate and create provisioning profiles:
#     https://appstoreconnect.apple.com/access/integrations/api → Team Keys → +
#     Download the .p8 file (Apple only lets you download it once) and note the key ID and the
#     issuer ID shown above the list.
#   - An app in App Store Connect with the bundle ID dev.ettlin.nicolas.letitgo and iOS as one
#     of its platforms.
#
# Nothing is written anywhere except GitHub Actions secrets for this repository.

set -euo pipefail

bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

say() { printf '%s\n' "$*"; }
step() { printf '\n%s%s%s\n' "$bold" "$*" "$reset"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v gh > /dev/null || fail "GitHub CLI not found. Install it with: brew install gh"
gh auth status > /dev/null 2>&1 || fail "GitHub CLI is not logged in. Run: gh auth login"
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || fail "Run this from inside the Let It Go repository checkout."

step "1/3  App Store Connect API key"
read -r -p ".p8 path: " p8_path
p8_path="${p8_path/#\~/$HOME}"
[ -f "$p8_path" ] || fail "No file at $p8_path"
grep -q 'BEGIN PRIVATE KEY' "$p8_path" || fail "$p8_path doesn't look like an App Store Connect API key."
read -r -p "Key ID: " key_id
[ -n "$key_id" ] || fail "The key ID must not be empty."
read -r -p "Issuer ID: " issuer_id
[ -n "$issuer_id" ] || fail "The issuer ID must not be empty."

say "Checking the key against Apple…"
xcrun notarytool history --key "$p8_path" --key-id "$key_id" --issuer "$issuer_id" > /dev/null \
  || fail "Apple rejected this key. Check the .p8 file, the key ID and the issuer ID."

step "2/3  Team ID"
team_id=""
if gh secret list --repo "$repo" | grep -q '^APPLE_TEAM_ID\b'; then
  say "APPLE_TEAM_ID is already set (by just setup-signing); keeping it."
else
  read -r -p "Apple Developer team ID: " team_id
  [[ "$team_id" =~ ^[A-Z0-9]{10}$ ]] || fail "A team ID is 10 letters and digits."
fi

step "3/3  Uploading secrets to $repo"
base64 -i "$p8_path" | gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo "$repo"
gh secret set APP_STORE_CONNECT_KEY_ID --repo "$repo" --body "$key_id"
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$repo" --body "$issuer_id"
[ -z "$team_id" ] || gh secret set APPLE_TEAM_ID --repo "$repo" --body "$team_id"

say
say "Done. The next push to main (or: gh workflow run CI --ref main) uploads the iOS app to TestFlight."
