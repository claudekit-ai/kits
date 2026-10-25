#!/usr/bin/env bash
# PR Review: print everything needed to review the current branch in one go.
# Resolves the base, then prints commits, a diffstat and the diff itself.
# Read-only: runs git read commands only and never touches the network.
#
# Usage: collect-diff.sh [base-ref] [max-diff-lines]
#   base-ref        Default: origin/HEAD's branch, then main, then master
#   max-diff-lines  Default: 3000. Larger diffs print the file list only.
set -uo pipefail

die() { printf 'pr-review: %s\n' "$1" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."

base=${1:-}
max_lines=${2:-3000}
case "$base" in -*) die "base-ref must not start with '-'." ;; esac
case "$max_lines" in ''|*[!0-9]*) die "max-diff-lines must be a whole number." ;; esac

if [ -z "$base" ]; then
  default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  for candidate in "$default" main master origin/main origin/master; do
    [ -n "$candidate" ] || continue
    if git rev-parse --verify --quiet "$candidate^{commit}" >/dev/null; then base=$candidate; break; fi
  done
  [ -n "$base" ] || die "could not find a base branch. Pass one, for example: main"
fi
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "base '$base' is not a commit in this repository."

head_name=$(git rev-parse --abbrev-ref HEAD)
merge_base=$(git merge-base "$base" HEAD) || die "'$base' and HEAD share no history."

echo "BRANCH: $head_name"
echo "BASE: $base"
echo "MERGE_BASE: $(git rev-parse --short "$merge_base")"
echo
echo "== Commits on this branch =="
git log --no-merges --format='%h %s' "$merge_base..HEAD"
echo
echo "== Uncommitted changes (not part of the review diff) =="
status=$(git status --short)
if [ -n "$status" ]; then printf '%s\n' "$status"; else echo "none"; fi
echo
echo "== Diffstat =="
git diff --stat "$merge_base" HEAD
echo
diff_lines=$(git diff "$merge_base" HEAD | wc -l | tr -d ' ')
if [ "$diff_lines" -eq 0 ]; then
  echo "== Diff =="
  echo "No committed changes between $base and HEAD."
elif [ "$diff_lines" -le "$max_lines" ]; then
  echo "== Diff ($diff_lines lines) =="
  git diff --unified=3 "$merge_base" HEAD
else
  echo "== Diff too large ($diff_lines lines, limit $max_lines) =="
  echo "Review file by file with: git diff $(git rev-parse --short "$merge_base") HEAD -- <path>"
  git diff --name-only "$merge_base" HEAD
fi
