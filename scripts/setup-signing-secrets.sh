#!/usr/bin/env bash
#
# Uploads the repository secrets that .github/workflows/ci.yml needs to publish signed,
# notarized releases. Run this on your Mac from the repository root:
#
#     just setup-signing
#
# Requirements:
#   - The GitHub CLI, logged in:  brew install gh && gh auth login
#   - A "Developer ID Application" certificate in your login keychain
#     (Xcode → Settings → Accounts → your team → Manage Certificates → + → Developer ID Application)
#   - An app-specific password for your Apple ID: https://account.apple.com → Sign-In and Security
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

step "1/4  Looking for a Developer ID Application certificate"
identity=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 'Developer ID Application' | sed -E 's/^.*"(.*)"$/\1/' || true)
if [ -z "$identity" ]; then
  say "None found in your keychain. Create one, then re-run this script:"
  say "  Xcode → Settings → Accounts → select your team → Manage Certificates → + → Developer ID Application"
  exit 1
fi
team_id=$(printf '%s' "$identity" | sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p')
[ -n "$team_id" ] || fail "Could not read the team ID from \"$identity\"."
say "Found: $identity"
say "Team ID: $team_id"

step "2/4  Export the certificate as a .p12 file"
say "In Keychain Access → login → My Certificates, expand \"$identity\","
say "select the certificate AND its private key, right-click → Export 2 items…, choose the .p12 format"
say "and a password. Then enter the path to that file here."
read -r -p ".p12 path: " p12_path
p12_path="${p12_path/#\~/$HOME}"
[ -f "$p12_path" ] || fail "No file at $p12_path"
read -r -s -p ".p12 password: " p12_password
printf '\n'
[ -n "$p12_password" ] || fail "The .p12 password must not be empty."

step "3/4  Notarization credentials"
read -r -p "Apple ID (email) for notarytool: " apple_id
[ -n "$apple_id" ] || fail "Apple ID must not be empty."
read -r -s -p "App-specific password for that Apple ID: " app_password
printf '\n'
[ -n "$app_password" ] || fail "App-specific password must not be empty."

say "Checking the credentials against Apple's notary service…"
xcrun notarytool history --apple-id "$apple_id" --team-id "$team_id" --password "$app_password" > /dev/null \
  || fail "Apple rejected these credentials. Check the Apple ID, the app-specific password, and that the account belongs to team $team_id."

step "4/4  Uploading secrets to $repo"
base64 -i "$p12_path" | gh secret set MACOS_SIGNING_CERTIFICATE_P12 --repo "$repo"
gh secret set MACOS_SIGNING_CERTIFICATE_PASSWORD --repo "$repo" --body "$p12_password"
gh secret set APPLE_TEAM_ID --repo "$repo" --body "$team_id"
gh secret set NOTARY_APPLE_ID --repo "$repo" --body "$apple_id"
gh secret set NOTARY_PASSWORD --repo "$repo" --body "$app_password"

say
say "Done. The next push to main (or: gh workflow run CI --ref main) publishes a signed, notarized release."
