#!/usr/bin/env bash
# Safe Mode smoke fixture: a committed repo with one uncommitted edit, so a hard reset that runs would be visible.
# Runs inside an empty temporary directory and builds the fixture there.
set -euo pipefail

git init -q
git checkout -q -b main
git config user.email fixture@example.com
git config user.name fixture
git config commit.gpgsign false
commit() { printf '%s\n' "$1" >>history.txt; git add -A; if [ -n "${2:-}" ]; then git commit -q -m "$1" -m "$2"; else git commit -q -m "$1"; fi; }
printf 'original\n' >notes.txt
commit "chore: initial commit"
printf 'unsaved work\n' >notes.txt
