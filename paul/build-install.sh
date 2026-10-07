#!/usr/bin/env bash
# Build Handy from this checkout, sign it with a stable Apple Development identity,
# and install it to /Applications. A stable identity keeps macOS's Accessibility and
# Microphone grants across rebuilds; ad-hoc signing loses them on every build.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_dest="/Applications/Handy.app"
cli_link="$HOME/.local/bin/handy"

identity="${HANDY_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning |
  sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)}"
if [[ -z "$identity" ]]; then
  echo "No Apple Development signing identity found; set HANDY_SIGNING_IDENTITY." >&2
  exit 1
fi
echo "Signing identity: $identity"

cd "$repo_root"
bun install
APPLE_SIGNING_IDENTITY="$identity" CMAKE_POLICY_VERSION_MINIMUM=3.5 \
  bun run tauri build --bundles app --config paul/tauri.paul.json

built_app="$repo_root/src-tauri/target/release/bundle/macos/Handy.app"
codesign --verify --deep --strict "$built_app"

if pgrep -x Handy >/dev/null; then
  osascript -e 'quit app "Handy"' || true
  for _ in {1..20}; do pgrep -x Handy >/dev/null || break; sleep 0.5; done
  if pgrep -x Handy >/dev/null; then
    echo "Handy is still running; quit it and re-run." >&2
    exit 1
  fi
fi

rm -rf "$app_dest"
ditto "$built_app" "$app_dest"
codesign --verify --deep --strict "$app_dest"

mkdir -p "$(dirname "$cli_link")"
ln -sf "$app_dest/Contents/MacOS/Handy" "$cli_link"

codesign -dv "$app_dest" 2>&1 | grep -E '^(Identifier|Authority)=' | head -2
echo "Installed $app_dest; CLI at $cli_link"
