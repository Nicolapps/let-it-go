#!/bin/bash
#
# Captures the App Store screenshots of the iOS app in the simulator, one per
# display size App Store Connect asks for, into screenshots/ios/.
#
#   scripts/app-store-screenshots.sh [name ...]
#
# With no names, every device below is captured. Each screenshot shows the app
# as it opens, under the status bar Apple uses in its own: 9:41, full signal and
# a full battery. The files are PNGs without an alpha channel, which App Store
# Connect refuses, named after their size in pixels.
#
# simctl can't open or close an iPhone Duo. Whichever of its displays is lit once
# the simulator has booted is captured first, normally the outer one; when run
# from a terminal, the script then waits for you to unfold the device in Device
# Hub before it captures the other.

set -euo pipefail
cd "$(dirname "$0")/.."

bundle_id=dev.ettlin.nicolas.letitgo
app="build/Build/Products/Release-iphonesimulator/Let It Go.app"
output=screenshots/ios

# The app takes a while to draw its first frame on a simulator that just booted.
settle=${SETTLE_SECONDS:-20}

# The name in the file, then a simulator of that size class. App Store Connect
# scales the large iPhone and the 13-inch iPad down for the sizes not listed.
devices=(
    "iphone-large:iPhone 18 Pro Max"
    "iphone-medium:iPhone 18 Pro"
    "ipad-13:iPad Pro 13-inch (M5)"
    "iphone-duo:iPhone Duo"
)

work=$(mktemp -d)
captured=()
# The simulator being captured, whose clock is to be put back whatever happens.
current=

# The simulator with this name on the newest runtime that has one.
udid_of() {
    xcrun simctl list devices available -j | jq -r --arg name "$1" '
        .devices | to_entries
        | map(select(.key | test("SimRuntime\\.iOS-")))
        | sort_by(.key | capture("iOS-(?<major>[0-9]+)-(?<minor>[0-9]+)") | [(.major | tonumber), (.minor | tonumber)])
        | reverse | map(.value[] | select(.name == $name) | .udid) | first // empty'
}

preferences_of() {
    echo "$HOME/Library/Developer/CoreSimulator/Devices/$1/data/Library/Preferences/.GlobalPreferences.plist"
}

# A simulator copies the Mac's 24-hour setting, which shows the time as 09:41.
# There's no simctl for it, and the simulator only reads the file as it boots.
use_12_hour_clock() {
    local preferences
    preferences=$(preferences_of "$1")
    if [[ ! -f $preferences ]]; then
        # Never booted, so it has no preferences yet.
        xcrun simctl boot "$1"
        xcrun simctl bootstatus "$1" -b >/dev/null
        xcrun simctl shutdown "$1"
    fi
    plutil -extract AppleICUForce24HourTime raw "$preferences" >"$work/$1.24-hour" 2>/dev/null || echo unset >"$work/$1.24-hour"
    plutil -extract AppleICUForce12HourTime raw "$preferences" >"$work/$1.12-hour" 2>/dev/null || echo unset >"$work/$1.12-hour"
    plutil -replace AppleICUForce24HourTime -bool NO "$preferences"
    plutil -replace AppleICUForce12HourTime -bool YES "$preferences"
}

restore_clock() {
    local preferences key value
    preferences=$(preferences_of "$1")
    for key in 24 12; do
        value=$(cat "$work/$1.$key-hour")
        if [[ $value == unset ]]; then
            plutil -remove "AppleICUForce${key}HourTime" "$preferences" 2>/dev/null || true
        else
            plutil -replace "AppleICUForce${key}HourTime" -bool "$value" "$preferences"
        fi
    done
}

cleanup() {
    if [[ -n $current ]]; then
        xcrun simctl shutdown "$current" 2>/dev/null || true
        restore_clock "$current"
    fi
    rm -rf "$work"
}
trap cleanup EXIT

# Starts the app afresh, so that it isn't caught scrolled or mid-transition.
launch() {
    xcrun simctl terminate "$1" "$bundle_id" 2>/dev/null || true
    xcrun simctl launch "$1" "$bundle_id" >/dev/null
    sleep "$settle"
}

# Saves what's on the device's display, or on the lit one of iPhone Duo's two.
capture() {
    local udid=$1 name=$2 displays display shot width height file
    if xcrun simctl io "$udid" screenshot --type=png "$work/shot.png" 2>"$work/error"; then
        displays=("")
    else
        # "Cannot choose between 2 displays. Specify one with --display: ..."
        displays=($(grep -o -- '--display=[0-9]*' "$work/error" || true))
        [[ ${#displays[@]} -gt 0 ]] || { cat "$work/error" >&2; return 1; }
    fi

    for display in "${displays[@]}"; do
        shot="$work/shot$display.png"
        [[ -z $display ]] || xcrun simctl io "$udid" screenshot --type=png "$display" "$shot" 2>/dev/null
        # A display that's off comes out black, which compresses to almost nothing.
        [[ $(stat -f %z "$shot") -gt 200000 ]] || continue
        width=$(sips -g pixelWidth "$shot" | awk '/pixelWidth/ { print $2 }')
        height=$(sips -g pixelHeight "$shot" | awk '/pixelHeight/ { print $2 }')
        file="$output/$name-${width}x$height.png"
        mv "$shot" "$file"
        captured+=("$file")
        echo "  $file"
    done
}

shoot() {
    local name=$1 simulator=$2 udid
    udid=$(udid_of "$simulator")
    if [[ -z $udid ]]; then
        echo "Skipping $name: there's no \"$simulator\" simulator" >&2
        return
    fi

    echo "$simulator"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    use_12_hour_clock "$udid"
    current=$udid
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b >/dev/null
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override --time 9:41 \
        --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --operatorName "" \
        --batteryState discharging --batteryLevel 100
    xcrun simctl install "$udid" "$app"

    launch "$udid"
    capture "$udid" "$name"

    if [[ $simulator == "iPhone Duo" && -t 0 ]]; then
        # Device Hub is inside Xcode, where `open -a` doesn't look.
        open "$(xcode-select -p)/../Applications/DeviceHub.app" || true
        read -r -p "  Unfold the iPhone Duo in Device Hub, then press Return (or type s to skip): " answer || answer=s
        if [[ $answer != s ]]; then
            launch "$udid"
            capture "$udid" "$name"
        fi
    fi

    xcrun simctl shutdown "$udid"
    restore_clock "$udid"
    current=
}

xcodebuild -project "Let It Go/Let It Go.xcodeproj" -scheme "Let It Go (iOS)" -configuration Release \
    -destination "generic/platform=iOS Simulator" -derivedDataPath build -quiet \
    CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" GIT_COMMIT="$(git rev-parse --short HEAD)" build

mkdir -p "$output"
for device in "${devices[@]}"; do
    name=${device%%:*}
    if [[ $# -eq 0 || " $* " == *" $name "* ]]; then
        shoot "$name" "${device#*:}"
    fi
done

if [[ ${#captured[@]} -gt 0 ]]; then
    swift scripts/opaque-png.swift "${captured[@]}"
fi
