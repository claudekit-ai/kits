#!/usr/bin/env bash
# Token Diet: list what Claude Code loads into context at session start for a
# project, with sizes, so you can see what to trim. Read-only; changes nothing.
#
# Usage: context-audit.sh [project-dir] [user-config-dir]
#   project-dir      Default: current directory
#   user-config-dir  Default: $CLAUDE_CONFIG_DIR or ~/.claude
#
# Sizes are lines and bytes, not tokens. Run /context in Claude Code for the
# real token counts.
set -uo pipefail

project=${1:-$PWD}
user_dir=${2:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}
[ -d "$project" ] || { echo "token-diet: not a directory: $project" >&2; exit 1; }
project=$(cd "$project" && pwd)
[ -d "$user_dir" ] && user_dir=$(cd "$user_dir" && pwd)

LINE_LIMIT=200  # CLAUDE.md target from the Claude Code memory docs
total_bytes=0
over=0

size_row() {
  # $1 label, $2 file
  local lines bytes flag=""
  lines=$(wc -l <"$2" | tr -d ' ')
  bytes=$(wc -c <"$2" | tr -d ' ')
  total_bytes=$((total_bytes + bytes))
  if [ "$lines" -gt "$LINE_LIMIT" ]; then flag="  <-- over $LINE_LIMIT lines"; over=$((over + 1)); fi
  printf '  %-9s %6s lines %8s bytes  %s%s\n' "$1" "$lines" "$bytes" "$2" "$flag"
}

# Has YAML frontmatter with a paths: key, so it loads only for matching files.
has_paths() { awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit 1} /^paths:/{found=1; exit 0} END{exit !found}' "$1"; }

imports_of() {
  # @path imports outside fenced code blocks and code spans.
  awk '/^[[:space:]]*```/{fence=!fence; next} !fence{gsub(/`[^`]*`/, ""); print}' "$1" \
    | grep -oE '(^|[[:space:]])@[~A-Za-z0-9_./-]+' | sed -E 's/^[[:space:]]*@//' | sort -u
}

report_imports() {
  local file=$1 dir imp path
  dir=$(dirname "$file")
  while IFS= read -r imp; do
    [ -n "$imp" ] || continue
    case "$imp" in
      "~/"*) path="$HOME/${imp:2}" ;;
      /*) path=$imp ;;
      *) path="$dir/$imp" ;;
    esac
    if [ -f "$path" ]; then size_row "import" "$path"; else printf '  %-9s %s (not found)\n' "import" "$path"; fi
  done < <(imports_of "$file")
}

echo "== Loaded at every session start =="
echo "User scope ($user_dir):"
for f in "$user_dir/CLAUDE.md"; do
  [ -f "$f" ] && { size_row "memory" "$f"; report_imports "$f"; }
done
if [ -d "$user_dir/rules" ]; then
  while IFS= read -r f; do
    if has_paths "$f"; then continue; fi
    size_row "rule" "$f"
  done < <(find "$user_dir/rules" -name '*.md' -type f 2>/dev/null | sort)
fi

echo "Project and parent directories:"
dir=$project
while :; do
  for name in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do
    f="$dir/$name"
    # ~/.claude/CLAUDE.md is the user file, already listed above.
    [ "$f" = "$user_dir/CLAUDE.md" ] && continue
    [ -f "$f" ] && { size_row "memory" "$f"; report_imports "$f"; }
  done
  [ "$dir" = "/" ] && break
  dir=$(dirname "$dir")
done
if [ ! -f "$project/CLAUDE.md" ] && [ ! -f "$project/.claude/CLAUDE.md" ] && [ ! -f "$project/CLAUDE.local.md" ] && [ -f "$project/AGENTS.md" ]; then
  size_row "agents" "$project/AGENTS.md"
fi

always=0
scoped=0
if [ -d "$project/.claude/rules" ]; then
  while IFS= read -r f; do
    if has_paths "$f"; then scoped=$((scoped + 1)); continue; fi
    always=$((always + 1))
    size_row "rule" "$f"
  done < <(find "$project/.claude/rules" -name '*.md' -type f 2>/dev/null | sort)
fi

echo
echo "== Loaded on demand (not counted above) =="
nested=$(find "$project" -mindepth 2 \( -name node_modules -o -name .git -o -name dist -o -name build -o -name vendor \) -prune -o \( -name CLAUDE.md -o -name CLAUDE.local.md \) -type f -print 2>/dev/null | grep -v "^$project/.claude/CLAUDE.md$" | wc -l | tr -d ' ')
echo "  Subdirectory CLAUDE.md files: $nested (load when Claude works in that folder)"
echo "  Path-scoped project rules:    $scoped (load when matching files are read)"

count_skills() { [ -d "$1" ] && find "$1" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0; }
echo "  Project skills: $(count_skills "$project/.claude/skills")   User skills: $(count_skills "$user_dir/skills")"
echo "  (Skill bodies load when invoked; every name and description sits in the skill listing.)"

echo
echo "== MCP servers in project .mcp.json =="
if [ -f "$project/.mcp.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -r '(.mcpServers // {}) | keys | if length == 0 then "  none" else (("  " + (length|tostring) + " configured: ") + join(", ")) end' "$project/.mcp.json" 2>/dev/null \
      || echo "  .mcp.json is not valid JSON"
  else
    echo "  .mcp.json present (install jq to list servers)"
  fi
else
  echo "  no .mcp.json (user and local servers: run /mcp)"
fi

echo
echo "== Summary =="
printf '  Always-loaded instruction text: %s bytes across the files above\n' "$total_bytes"
printf '  Files over %s lines: %s\n' "$LINE_LIMIT" "$over"
printf '  Always-on project rules (no paths:): %s\n' "$always"
echo "  Real token counts: run /context. Plan usage by source: run /usage."
