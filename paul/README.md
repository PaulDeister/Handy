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

`build-install.sh` signs with the first `Apple Development` identity in the keychain, or
`HANDY_SIGNING_IDENTITY` if set. A stable identity keeps the Accessibility and Microphone
grants across rebuilds; upstream's ad-hoc signature loses them on every build.

## Settings

`settings.base.json` holds public-safe values. Private custom words, the cleanup prompt
glossary and the post-processing provider live in `~/.config/handy-paul/settings.local.json`
and are never committed; `settings.local.example.json` shows the format. The API key is read
from a command at apply time and lands only in Handy's own settings store, never in either
overlay file.

| Hotkey             | Action                                                                |
| ------------------ | --------------------------------------------------------------------- |
| Option+Space       | Dictate locally. Hold to talk, or tap to start and tap again to stop. |
| Option+Shift+Space | Dictate, then clean up the text through the post-processing provider. |
| Escape             | Cancel the recording.                                                 |

Dictation pastes with Cmd+V and never presses Enter.
