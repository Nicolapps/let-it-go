project := "Let It Go/Let It Go.xcodeproj"
scheme := "Let It Go"
derived := "build"

# List available recipes
default:
    @just --list

# Build the app and extension (config: Debug or Release)
build config="Debug":
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration {{config}} \
        -derivedDataPath {{derived}} -quiet build

# Build, then launch the app so Safari picks up the extension
run config="Debug": (build config) quit
    open "{{derived}}/Build/Products/{{config}}/Let It Go.app"

# Quit the running app, if any, and wait for it to exit so `open` doesn't race it
quit:
    -pkill -x "Let It Go"
    while pgrep -x "Let It Go" >/dev/null; do sleep 0.1; done

# Build Release and copy the app into /Applications
install: (build "Release") quit
    rm -rf "/Applications/Let It Go.app"
    cp -R "{{derived}}/Build/Products/Release/Let It Go.app" /Applications/
    open "/Applications/Let It Go.app"

# Validate the extension's JSON, JavaScript and rule regexes
lint:
    jq empty extension/manifest.json extension/rules.json
    node --check extension/fallback.js
    node --check extension/background.js
    node --check extension/popup/popup.js
    node -e 'for (const r of require("./extension/rules.json")) new RegExp(r.condition.regexFilter)'
    node scripts/generate-rules.js --check

# Regenerate extension/rules.json from scripts/generate-rules.js
rules:
    node scripts/generate-rules.js

# Show where a search URL would be redirected by rules.json
try url:
    #!/usr/bin/env node
    const url = {{quote(url)}};
    for (const rule of require(process.cwd() + "/extension/rules.json")) {
      const re = new RegExp(rule.condition.regexFilter);
      if (re.test(url)) {
        const sub = rule.action.redirect.regexSubstitution.replace(/\\(\d)/g, (_, n) => "$" + n);
        console.log(`rule ${rule.id} → ${url.replace(re, sub)}`);
        process.exit(0);
      }
    }
    console.log("no rule matched (fallback.js may still handle it)");

# Upload the code-signing and notarization secrets so CI publishes signed releases
setup-signing:
    scripts/setup-signing-secrets.sh

# Remove build output
clean:
    rm -rf {{derived}}
