#!/usr/bin/env bash
# Static test for release-notes: group commits in a fixture repo and check the output.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
kit=$(cd "$here/.." && pwd)
script="$kit/skills/draft/scripts/group-commits.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() { if grep -qF -- "$2" <<<"$1"; then echo "ok    contains: $2"; else echo "FAIL  missing: $2"; fail=1; fi; }
reject() { if grep -qF -- "$2" <<<"$1"; then echo "FAIL  unexpected: $2"; fail=1; else echo "ok    absent: $2"; fi; }

(cd "$tmp" && bash "$here/fixture.sh")

out=$(cd "$tmp" && bash "$script")
expect "$out" "# Release notes draft: v1.0.0..HEAD"
expect "$out" "8 commits (merges excluded)."
expect "$out" "## Breaking changes"
expect "$out" "drop Node 18 support"
if [ "$(grep -c 'drop Node 18 support' <<<"$out")" -eq 1 ]; then echo "ok    breaking commit listed once"; else echo "FAIL  breaking commit duplicated"; fail=1; fi
expect "$out" "**core:** split the parser"
expect "$out" "## Features"
expect "$out" "**api:** add /health endpoint"
expect "$out" "## Bug fixes"
expect "$out" "## Performance"
expect "$out" "## Documentation"
expect "$out" "## Other changes"
expect "$out" "- Update random thing"
expect "$out" "## Maintenance"
reject "$out" "initial commit"
# Breaking changes come before features.
if [ "$(grep -n '## Breaking' <<<"$out" | cut -d: -f1)" -lt "$(grep -n '## Features' <<<"$out" | cut -d: -f1)" ]; then
  echo "ok    breaking changes listed first"
else
  echo "FAIL  breaking changes not first"; fail=1
fi

out=$(cd "$tmp" && bash "$script" v1.0.0 HEAD~6)
expect "$out" "2 commits (merges excluded)."

(cd "$tmp" && bash "$script" no-such-ref >/dev/null 2>&1); code=$?
if [ "$code" -eq 1 ]; then echo "ok    exit 1 on unknown ref"; else echo "FAIL  unknown ref exit $code"; fail=1; fi
(cd "$tmp" && bash "$script" --output=x >/dev/null 2>&1); code=$?
if [ "$code" -eq 1 ]; then echo "ok    exit 1 on option-like ref"; else echo "FAIL  option-like ref exit $code"; fail=1; fi
norepo=$(mktemp -d)
(cd "$norepo" && bash "$script" >/dev/null 2>&1); code=$?
rmdir "$norepo"
if [ "$code" -eq 1 ]; then echo "ok    exit 1 outside a git repo"; else echo "FAIL  outside repo exit $code"; fail=1; fi

exit "$fail"
