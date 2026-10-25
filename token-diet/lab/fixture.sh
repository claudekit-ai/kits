#!/usr/bin/env bash
# Token Diet smoke fixture: CLAUDE.md over 200 lines with an import, one always-on rule, one path-scoped rule, a nested CLAUDE.md and three MCP servers.
# Runs inside an empty temporary directory and builds the fixture there.
set -euo pipefail

mkdir -p .claude/rules docs packages/api
{
  echo "# Project instructions"
  echo
  echo "See @docs/conventions.md for naming."
  for i in $(seq 1 120); do echo "- General rule $i: keep functions small and named clearly."; done
  echo
  echo "## Release process"
  for i in $(seq 1 80); do echo "$i. Release step $i: run the checklist item and record it."; done
  echo
  echo "## Database migrations"
  for i in $(seq 1 40); do echo "- Migration rule $i for files under db/migrations."; done
} >CLAUDE.md
for i in $(seq 1 30); do echo "- Naming convention $i."; done >docs/conventions.md
printf 'Always run the linter before finishing.\n' >.claude/rules/lint.md
printf -- '---\npaths:\n  - "src/**/*.ts"\n---\nUse strict TypeScript.\n' >.claude/rules/typescript.md
printf 'API package notes.\n' >packages/api/CLAUDE.md
printf '{"mcpServers":{"github":{"command":"gh-mcp"},"postgres":{"command":"pg-mcp"},"browser":{"command":"browser-mcp"}}}\n' >.mcp.json
