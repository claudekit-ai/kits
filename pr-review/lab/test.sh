#!/usr/bin/env bash
# Static test for pr-review: collect the diff of a fixture branch and check the output.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
kit=$(cd "$here/.." && pwd)
script="$kit/skills/review/scripts/collect-diff.sh"
tmp=$(mktemp -d)
norepo=$(mktemp -d)
trap 'rm -rf "$tmp" "$norepo"' EXIT
fail=0
expect() { if grep -qF -- "$2" <<<"$1"; then echo "ok    contains: $2"; else echo "FAIL  missing: $2"; fail=1; fi; }

(cd "$tmp" && bash "$here/fixture.sh")

# Base auto-detected (main).
out=$(cd "$tmp" && bash "$script")
expect "$out" "BRANCH: feat/search"
expect "$out" "BASE: main"
expect "$out" "feat: add user search and paging"
expect "$out" "src/users.js"
expect "$out" "== Diff ("
expect "$out" "+export function searchUsers(db, name) {"
expect "$out" "Uncommitted changes (not part of the review diff) =="

# Explicit base and a tiny line limit switch to the file list.
out=$(cd "$tmp" && bash "$script" main 5)
expect "$out" "== Diff too large"
expect "$out" "src/users.js"

# Uncommitted edits are reported, not reviewed.
echo "// wip" >>"$tmp/src/users.js"
out=$(cd "$tmp" && bash "$script" main)
expect "$out" "M src/users.js"
git -C "$tmp" checkout -q -- src/users.js

check_exit() {
  local want=$1 label=$2; shift 2
  (cd "$1" && shift && bash "$script" "$@" >/dev/null 2>&1)
  local code=$?
  if [ "$code" -eq "$want" ]; then echo "ok    exit $want: $label"; else echo "FAIL  $label exit $code"; fail=1; fi
}
check_exit 1 "unknown base" "$tmp" no-such-branch
check_exit 1 "option-like base" "$tmp" --output=/tmp/x
check_exit 1 "bad line limit" "$tmp" main abc
check_exit 1 "outside a git repo" "$norepo"

exit "$fail"
