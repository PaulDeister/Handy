#!/usr/bin/env bash
# Build Handy from this checkout, sign it with a stable local identity, and install it
# to /Applications. A stable identity keeps macOS's Accessibility and
# Microphone grants across rebuilds; ad-hoc signing loses them on every build.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_dest="/Applications/Handy.app"
cli_link="$HOME/.local/bin/handy"

identity="${HANDY_SIGNING_IDENTITY:-Handy Local Signing}"
if ! security find-identity -p codesigning | grep -qF "\"$identity\""; then
  echo "Signing identity '$identity' not in the keychain; see paul/README.md." >&2
  exit 1
fi
echo "Signing identity: $identity"

cd "$repo_root"
bun install
APPLE_SIGNING_IDENTITY="$identity" CMAKE_POLICY_VERSION_MINIMUM=3.5 \
  bun run tauri build --bundles app --config paul/tauri.paul.json

built_app="$repo_root/src-tauri/target/release/bundle/macos/Handy.app"
codesign --verify --deep --strict "$built_app"

if pgrep -x handy >/dev/null; then
  osascript -e 'quit app "Handy"' || true
  for _ in {1..20}; do pgrep -x handy >/dev/null || break; sleep 0.5; done
  if pgrep -x handy >/dev/null; then
    echo "Handy is still running; quit it and re-run." >&2
    exit 1
  fi
fi

rm -rf "$app_dest"
ditto "$built_app" "$app_dest"
codesign --verify --deep --strict "$app_dest"

mkdir -p "$(dirname "$cli_link")"
ln -sf "$app_dest/Contents/MacOS/handy" "$cli_link"

codesign -dvv "$app_dest" 2>&1 | grep -E '^(Identifier|Authority)=' | head -2
echo "Installed $app_dest; CLI at $cli_link"
