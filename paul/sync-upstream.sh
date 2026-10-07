#!/usr/bin/env bash
# Merge an upstream Handy release tag into the `paul` branch, push, and rebuild.
# Usage: paul/sync-upstream.sh v0.9.9   (no argument: the newest upstream v* tag)
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean; commit or stash first." >&2
  exit 1
fi
if [[ "$(git branch --show-current)" != "paul" ]]; then
  echo "Run this on the paul branch." >&2
  exit 1
fi

git pull --ff-only origin paul
git fetch upstream --tags --force
tag="${1:-$(git tag -l 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)}"
if git merge-base --is-ancestor "$tag" HEAD; then
  echo "paul already contains $tag."
  exit 0
fi

git merge --no-edit "$tag"
git push origin paul
"$repo_root/paul/build-install.sh"
