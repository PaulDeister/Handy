# Paul's Handy build

This fork builds Handy on one Mac with a stable signing identity, upstream's auto-updater
pointed away, and a scripted set of settings. Everything fork-specific lives in this
directory, so merging an upstream release never conflicts.

## Branches

- `main` mirrors `cjpais/Handy` main.
- `paul` is the latest upstream release tag plus this directory. It is the default branch
  and the one to build.
- The `upstream` remote has its push URL disabled. Open PRs with
  `gh pr create --repo PaulDeister/Handy --base paul`, because gh otherwise targets the parent.

## Commands

| Task                                                             | Command                                       |
| ---------------------------------------------------------------- | --------------------------------------------- |
| Build, sign, install to /Applications, link `~/.local/bin/handy` | `paul/build-install.sh`                       |
| Merge a new upstream release and rebuild                         | `paul/sync-upstream.sh [vX.Y.Z]`              |
| Apply settings (quits and relaunches Handy)                      | `python3 -I paul/apply-settings.py`           |
| Preview the settings change                                      | `python3 -I paul/apply-settings.py --dry-run` |
| Toggle recording from a shell or script                          | `handy --toggle-transcription`                |

## Signing

`build-install.sh` signs with the `Handy Local Signing` identity, or
`HANDY_SIGNING_IDENTITY` if set. A stable identity keeps the Accessibility and Microphone
grants across rebuilds; upstream's ad-hoc signature loses them on every build.

`Handy Local Signing` is a self-signed code-signing certificate in the login keychain. macOS
lists it as untrusted, which codesign and the permission grants don't need. To create it on
a new Mac (needs OpenSSL 3, `brew install openssl@3`; macOS's built-in LibreSSL lacks `-legacy`):

```bash
cd "$(mktemp -d)"
openssl="$(brew --prefix openssl@3)/bin/openssl"
"$openssl" req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 \
  -subj "/CN=Handy Local Signing" -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning"
"$openssl" pkcs12 -export -legacy -inkey key.pem -in cert.pem -name "Handy Local Signing" \
  -out handy.p12 -passout pass:temp
security import handy.p12 -k ~/Library/Keychains/login.keychain-db -P temp -T /usr/bin/codesign
rm -f key.pem cert.pem handy.p12
```

## Settings

`settings.base.json` holds public-safe values. Private custom words, the cleanup prompt
glossary and the post-processing provider live in `~/.config/handy-paul/settings.local.json`
and are never committed; `settings.overlay.example.json` shows the format. The API key is read
from a command at apply time and is never written to an overlay file. It lands in Handy's
settings store and in the timestamped `settings_store.json.bak-*` backups the script leaves
beside it.

Handy's default hotkeys, which the scripts leave as they are:

| Hotkey             | Action                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Option+Space       | Dictate locally. Hold to talk, or tap to start and tap again to stop.                                                           |
| Option+Shift+Space | Dictate, then clean up the text through the post-processing provider. Active only when the overlay sets `post_process_enabled`. |
| Escape             | Cancel the recording.                                                                                                           |

Dictation pastes with Cmd+V and never presses Enter.
