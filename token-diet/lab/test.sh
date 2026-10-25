#!/usr/bin/env bash
# Static test for token-diet: audit a fixture project and check what it reports.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
kit=$(cd "$here/.." && pwd)
script="$kit/skills/audit/scripts/context-audit.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() { if grep -qF -- "$2" <<<"$1"; then echo "ok    contains: $2"; else echo "FAIL  missing: $2"; fail=1; fi; }
reject() { if grep -qF -- "$2" <<<"$1"; then echo "FAIL  unexpected: $2"; fail=1; else echo "ok    absent: $2"; fi; }

mkdir -p "$tmp/project" "$tmp/user/skills/demo"
(cd "$tmp/project" && bash "$here/fixture.sh")
printf 'Personal preferences.\n' >"$tmp/user/CLAUDE.md"
printf -- '---\nname: demo\ndescription: demo\n---\n' >"$tmp/user/skills/demo/SKILL.md"
before=$(cat "$tmp/project/CLAUDE.md" | cksum)

out=$(bash "$script" "$tmp/project" "$tmp/user")
code=$?
[ "$code" -eq 0 ] && echo "ok    exit 0" || { echo "FAIL  exit $code"; fail=1; }
expect "$out" "$tmp/user/CLAUDE.md"
expect "$out" "$tmp/project/CLAUDE.md  <-- over 200 lines"
expect "$out" "$tmp/project/docs/conventions.md"
expect "$out" "$tmp/project/.claude/rules/lint.md"
reject "$out" "rules/typescript.md"
expect "$out" "Subdirectory CLAUDE.md files: 1"
expect "$out" "Path-scoped project rules:    1"
expect "$out" "User skills: 1"
expect "$out" "3 configured: browser, github, postgres"
expect "$out" "Files over 200 lines: 1"
expect "$out" "Always-on project rules (no paths:): 1"
expect "$out" "run /context"
# Never prints token estimates.
reject "$out" "tokens:"

# Read-only.
[ "$(cat "$tmp/project/CLAUDE.md" | cksum)" = "$before" ] && echo "ok    CLAUDE.md unchanged" || { echo "FAIL  CLAUDE.md changed"; fail=1; }

# A lean project reports no files over the limit.
mkdir -p "$tmp/lean"
printf '# Lean\n- Run tests with npm test.\n' >"$tmp/lean/CLAUDE.md"
out=$(bash "$script" "$tmp/lean" "$tmp/user")
expect "$out" "Files over 200 lines: 0"
expect "$out" "no .mcp.json"

bash "$script" "$tmp/missing" >/dev/null 2>&1
code=$?
[ "$code" -eq 1 ] && echo "ok    exit 1 on missing dir" || { echo "FAIL  missing dir exit $code"; fail=1; }

exit "$fail"
