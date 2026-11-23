#!/usr/bin/env bash
#
# Uploads the repository secrets that .github/workflows/ci.yml needs to publish signed,
# notarized macOS releases. Run this on your Mac from the repository root:
#
#     just setup-signing
#
# It walks you through everything, with links. In short, you need:
#
#   1. A paid Apple Developer Program membership (99 USD/year), where you are the Account Holder
#      (only the Account Holder can create Developer ID certificates):
#        https://developer.apple.com/programs/enroll/
#   2. A "Developer ID Application" certificate, with its private key, in your login keychain.
#      Easiest: Xcode → Settings → Accounts → your team → Manage Certificates → + → Developer ID
#      Application. Apple's guide (also explains the browser-based way):
#        https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
#   3. An app-specific password for your Apple ID (used by the notary service):
#        https://account.apple.com → Sign-In and Security → App-Specific Passwords
#        https://support.apple.com/en-us/102654
#   4. The GitHub CLI, logged in:  brew install gh && gh auth login   (https://cli.github.com)
#
# Nothing is written anywhere except GitHub Actions secrets for this repository. GitHub secrets
# can't be read back, so to reuse the same certificate in another repository, run its copy of
# this script too: the same .p12, password and Apple ID work.

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

open_keychain_access() {
  # Keychain Access moved out of /Applications/Utilities in macOS 15.
  open -a "Keychain Access" 2>/dev/null \
    || open "/System/Library/CoreServices/Applications/Keychain Access.app" 2>/dev/null \
    || say "Open Keychain Access with Spotlight (⌘Space, then type “Keychain Access”)."
}

[ "$(uname)" = "Darwin" ] || fail "Run this on your Mac: it reads your keychain and talks to Apple's notary service."

if ! command -v gh > /dev/null; then
  fail "GitHub CLI not found. Install it with: brew install gh   (or see https://cli.github.com)"
fi
gh auth status > /dev/null 2>&1 || fail "GitHub CLI is not logged in. Run: gh auth login"
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || fail "Run this from inside the Let It Go repository checkout."

say "This uploads 5 secrets to ${bold}$repo${reset} so that CI can sign and notarize macOS releases."
note "Stop at any time with Ctrl-C: nothing is uploaded before step 5."

# ---------------------------------------------------------------------------------------------
step "1/5  Developer ID Application certificate"

identity=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 'Developer ID Application' | sed -E 's/^.*"(.*)"$/\1/' || true)

if [ -z "$identity" ]; then
  cat <<EOF
None found in your login keychain (with its private key). To create one:

  Requirements: a paid Apple Developer Program membership, and you must be the team's
  Account Holder. Enrol at https://developer.apple.com/programs/enroll/

  ${bold}Option A, with Xcode (simplest, it creates the private key for you):${reset}
    1. Open Xcode → Settings… (⌘,) → Accounts.
    2. Add your Apple ID with + if it isn't listed, then select your team on the right.
    3. Click “Manage Certificates…”.
    4. Click + at the bottom left → “Developer ID Application”.
    5. Close the sheet. The certificate and its private key are now in your login keychain.

  ${bold}Option B, in the browser:${reset}
    1. Create a certificate signing request: open Keychain Access, then in the menu bar
       Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…
       Enter your email and name, choose “Saved to disk”, and save the .certSigningRequest file.
    2. Go to https://developer.apple.com/account/resources/certificates/add
       choose “Developer ID Application”, Continue, keep the default (G2) sub-CA, upload the
       request, then download the .cer file.
    3. Double-click the .cer file to add it to your login keychain. It pairs with the private
       key that step 1 created on this Mac.
    Apple's guide: https://developer.apple.com/help/account/certificates/create-developer-id-certificates/

  ${bold}Already have one on another Mac?${reset} Export it there as a .p12 (step 2 of this script
  explains how) and double-click the .p12 on this Mac to import it. A certificate without its
  private key can't sign anything.

Then run this script again.
EOF
  if ask "Open Xcode now?"; then open -a Xcode || true; fi
  exit 1
fi

team_id=$(printf '%s' "$identity" | sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p')
[ -n "$team_id" ] || fail "Could not read the team ID from \"$identity\"."
say "Found: $identity"
say "Team ID: $team_id"
note "(The team ID is also shown at https://developer.apple.com/account → Membership details.)"

# ---------------------------------------------------------------------------------------------
step "2/5  Export the certificate and its private key as a .p12 file"
cat <<EOF
  1. Open Keychain Access.
  2. In the sidebar, select the “login” keychain, then the “My Certificates” tab.
  3. Find “${identity}”.
     It should have a disclosure triangle with a private key inside. If it doesn't, the key
     is not on this Mac: see the “Already have one on another Mac?” note in step 1.
  4. Select the certificate row, then File → Export Items…
     (or right-click → Export “${identity}”…).
  5. Choose the file format “Personal Information Exchange (.p12)” and save it,
     for example to ~/Desktop/developer-id.p12
  6. Choose a password for the file. You'll type it again below, and CI uses it to open the file.
  7. macOS then asks for your Mac login password, to allow exporting the private key.

EOF
if ask "Open Keychain Access now?"; then open_keychain_access; fi
say
note "Tip: you can drag the .p12 file from the Finder into this window to paste its path."
read -r -p ".p12 path: " p12_path
# Accept paths pasted with quotes or with backslash-escaped spaces (as Finder drag & drop does).
p12_path="${p12_path%"${p12_path##*[![:space:]]}"}"
p12_path="${p12_path#\'}"; p12_path="${p12_path%\'}"
p12_path="${p12_path#\"}"; p12_path="${p12_path%\"}"
p12_path="${p12_path//\\ / }"
p12_path="${p12_path/#\~/$HOME}"
[ -f "$p12_path" ] || fail "No file at $p12_path"
read -r -s -p ".p12 password: " p12_password
printf '\n'
[ -n "$p12_password" ] || fail "The .p12 password must not be empty: CI can't import a .p12 without one."
export P12_PASSWORD="$p12_password"  # passed to openssl via the environment, not the command line

say "Checking the file and the password…"
if ! openssl pkcs12 -in "$p12_path" -passin env:P12_PASSWORD -nokeys -noout 2>/dev/null \
  && ! openssl pkcs12 -legacy -in "$p12_path" -passin env:P12_PASSWORD -nokeys -noout 2>/dev/null; then
  fail "Could not open $p12_path with that password. Export it again and note the password."
fi
if ! openssl pkcs12 -in "$p12_path" -passin env:P12_PASSWORD -nocerts -nodes 2>/dev/null | grep -q 'PRIVATE KEY' \
  && ! openssl pkcs12 -legacy -in "$p12_path" -passin env:P12_PASSWORD -nocerts -nodes 2>/dev/null | grep -q 'PRIVATE KEY'; then
  fail "$p12_path has no private key. In Keychain Access, export the certificate that has a private key under it."
fi
say "OK: the file contains the certificate and its private key."

# ---------------------------------------------------------------------------------------------
step "3/5  Apple ID for notarization"
cat <<EOF
  The Apple ID you use for the developer account (team $team_id). Apple's notary service checks
  every release before macOS will open it without a warning.

EOF
read -r -p "Apple ID (email): " apple_id
[ -n "$apple_id" ] || fail "Apple ID must not be empty."

# ---------------------------------------------------------------------------------------------
step "4/5  App-specific password for that Apple ID"
cat <<EOF
  CI can't use your real Apple ID password (or two-factor codes), so it uses an app-specific
  password instead. To create one:

    1. Go to https://account.apple.com and sign in with $apple_id.
    2. Open “Sign-In and Security” → “App-Specific Passwords”.
       (Two-factor authentication must be on for this to appear.)
    3. Click + (or “Generate an app-specific password”), name it e.g. “GitHub notarization”.
    4. Copy the password it shows (xxxx-xxxx-xxxx-xxxx). Apple shows it only once.

    Apple's guide: https://support.apple.com/en-us/102654
  You can reuse the same app-specific password in several repositories, and revoke it there
  at any time.

EOF
if ask "Open account.apple.com now?"; then open "https://account.apple.com" || true; fi
read -r -s -p "App-specific password: " app_password
printf '\n'
[ -n "$app_password" ] || fail "App-specific password must not be empty."

say "Checking the credentials against Apple's notary service…"
xcrun notarytool history --apple-id "$apple_id" --team-id "$team_id" --password "$app_password" > /dev/null \
  || fail "Apple rejected these credentials. Check the Apple ID, the app-specific password, and that the account belongs to team $team_id."
say "OK: Apple accepted them."

# ---------------------------------------------------------------------------------------------
step "5/5  Uploading secrets to $repo"
base64 -i "$p12_path" | gh secret set MACOS_SIGNING_CERTIFICATE_P12 --repo "$repo"
gh secret set MACOS_SIGNING_CERTIFICATE_PASSWORD --repo "$repo" --body "$p12_password"
gh secret set APPLE_TEAM_ID --repo "$repo" --body "$team_id"
gh secret set NOTARY_APPLE_ID --repo "$repo" --body "$apple_id"
gh secret set NOTARY_PASSWORD --repo "$repo" --body "$app_password"

say
say "Done. The next push to main publishes a signed, notarized release. To start one now:"
say "  gh workflow run CI --ref main"
say
say "The .p12 file holds your private signing key. Keep it somewhere safe (a password manager"
say "is a good place) or delete it:"
say "  rm \"$p12_path\""
note "You'll need it again (or a fresh export) to set up signing in another repository."
