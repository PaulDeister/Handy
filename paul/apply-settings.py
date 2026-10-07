#!/usr/bin/env python3
"""Merge settings overlays into Handy's settings store, then restart Handy.

Overlays apply in order: paul/settings.base.json (public, in the repo), then the
private ~/.config/handy-paul/settings.local.json if present. Plain keys replace the
value in the store, except that object values merge key by key. Special keys:

  post_process_providers_patch       {provider_id: {field: value}} updates that provider
  post_process_prompts_upsert        [prompt, ...] replaces a prompt by id or appends it
  post_process_api_keys_from_command {provider_id: [argv...]} stores the command's stdout

Run it with `python3 -I paul/apply-settings.py [--dry-run] [--no-restart]`.
Handy must have been launched once so the store exists.
"""

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

STORE = Path.home() / "Library/Application Support/com.pais.handy/settings_store.json"
BASE = Path(__file__).resolve().parent / "settings.base.json"
LOCAL = Path.home() / ".config/handy-paul/settings.local.json"
APP = "/Applications/Handy.app"
SPECIAL = {
    "post_process_providers_patch",
    "post_process_prompts_upsert",
    "post_process_api_keys_from_command",
}
SECRET_KEYS = {"post_process_api_keys", "post_process_api_keys_from_command"}


def apply_overlay(settings, overlay, source):
    changed = []
    for key, value in overlay.items():
        if key.startswith("_"):
            continue
        if key == "post_process_providers_patch":
            providers = {p["id"]: p for p in settings.get("post_process_providers", [])}
            for pid, fields in value.items():
                if pid not in providers:
                    sys.exit(f"{source}: unknown post-process provider '{pid}'")
                providers[pid].update(fields)
            changed.append(key)
        elif key == "post_process_prompts_upsert":
            prompts = settings.setdefault("post_process_prompts", [])
            for prompt in value:
                existing = next((p for p in prompts if p["id"] == prompt["id"]), None)
                if existing is None:
                    prompts.append(prompt)
                else:
                    existing.update(prompt)
            changed.append(key)
        elif key == "post_process_api_keys_from_command":
            keys = settings.setdefault("post_process_api_keys", {})
            for pid, argv in value.items():
                argv = [os.path.expanduser(argv[0]), *argv[1:]]
                out = subprocess.run(argv, capture_output=True, text=True, check=True)
                keys[pid] = out.stdout.strip()
            changed.append(key)
        elif key not in settings:
            sys.exit(f"{source}: '{key}' is not a Handy setting (typo?)")
        elif isinstance(value, dict) and isinstance(settings[key], dict):
            settings[key].update(value)
            changed.append(key)
        else:
            settings[key] = value
            changed.append(key)
    return changed


def handy_running():
    return subprocess.run(["pgrep", "-x", "Handy"], capture_output=True).returncode == 0


def quit_handy():
    if not handy_running():
        return
    subprocess.run(["osascript", "-e", 'quit app "Handy"'], capture_output=True)
    for _ in range(20):
        if not handy_running():
            return
        time.sleep(0.5)
    sys.exit("Handy did not quit; quit it from the menu bar and re-run.")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="show changes, write nothing")
    parser.add_argument("--no-restart", action="store_true", help="leave Handy quit")
    args = parser.parse_args()

    if not STORE.exists():
        sys.exit(f"{STORE} not found: launch Handy once and finish onboarding first.")

    if not args.dry_run:
        quit_handy()

    store = json.loads(STORE.read_text())
    settings = store["settings"]
    before = json.loads(json.dumps(settings))

    changed = []
    for path in (BASE, LOCAL):
        if path.exists():
            changed += apply_overlay(settings, json.loads(path.read_text()), path)

    for key in sorted(set(changed) - SPECIAL):
        shown = "[redacted]" if key in SECRET_KEYS else json.dumps(settings[key])[:120]
        mark = "" if before.get(key) != settings[key] else " (unchanged)"
        print(f"{key} = {shown}{mark}")
    for key in sorted(set(changed) & SPECIAL):
        print(f"{key} applied")

    if args.dry_run:
        print("Dry run: nothing written.")
        return

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(STORE, STORE.with_name(f"{STORE.name}.bak-{stamp}"))
    tmp = STORE.with_name(f"{STORE.name}.tmp")
    tmp.write_text(json.dumps(store, indent=2))
    os.replace(tmp, STORE)
    print(f"Wrote {STORE} (backup .bak-{stamp})")

    if not args.no_restart:
        subprocess.run(["open", APP], check=True)
        print("Relaunched Handy.")


if __name__ == "__main__":
    main()
