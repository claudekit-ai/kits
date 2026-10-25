#!/usr/bin/env bash
# Release Notes smoke fixture: tag v1.0.0 followed by commits of every Conventional Commit kind.
# Runs inside an empty temporary directory and builds the fixture there.
set -euo pipefail

git init -q
git checkout -q -b main
git config user.email fixture@example.com
git config user.name fixture
git config commit.gpgsign false
commit() { printf '%s\n' "$1" >>history.txt; git add -A; if [ -n "${2:-}" ]; then git commit -q -m "$1" -m "$2"; else git commit -q -m "$1"; fi; }
commit "chore: initial commit"
git tag v1.0.0
commit "feat(api): add /health endpoint"
commit "fix: handle an empty config file"
commit "feat!: drop Node 18 support"
commit "refactor(core): split the parser" "BREAKING CHANGE: parse() now returns a Promise"
commit "docs: explain the config file"
commit "ci: cache pnpm store"
commit "Update random thing"
commit "perf: memoise route lookups"
