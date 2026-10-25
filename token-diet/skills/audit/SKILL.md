---
name: audit
description: Audit what Claude Code loads into context at session start (CLAUDE.md files, imports, always-on rules, skills, MCP servers) and suggest documented ways to trim it. Use when usage climbs fast, context fills early, or the user asks to slim CLAUDE.md.
argument-hint: "[project-dir]"
---

# Token Diet audit

Goal: show the user which always-loaded files cost context on every request, then suggest trims that use documented Claude Code features only. This audit is read-only. Do not edit, move or delete any file unless the user asks for a specific change after seeing the report.

## 1. Measure

Run the bundled script once with the Bash tool. Use `$ARGUMENTS` as the project directory if the user gave one, otherwise the current directory:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/context-audit.sh" $ARGUMENTS
```

It prints line and byte counts, not tokens. Never convert bytes to tokens or invent token numbers. For real token counts, tell the user to run `/context`; for what used their plan allowance, `/usage` (paid plans show a breakdown by skills, subagents, plugins and MCP servers).

## 2. Report

Write a short report with:

1. **Top three costs**: the largest always-loaded files, with their line counts.
2. **Over the target**: each CLAUDE.md over 200 lines. Anthropic's memory docs say to target under 200 lines per CLAUDE.md file, because longer files consume more context and reduce adherence.
3. **Suggested trims**, one line each, choosing only from these documented levers:
   - Move workflow-specific instructions (PR review steps, migration checklists, release steps) out of CLAUDE.md into a skill. Skills load their body only when invoked.
   - Move instructions that apply to part of the codebase into `.claude/rules/<topic>.md` with a `paths:` frontmatter list, so they load only when Claude works with matching files.
   - Imports (`@path`) organise a file but do not reduce context, because imported files load with the CLAUDE.md that imports them. Flag large imports.
   - Delete outdated or contradictory instructions. If two instructions conflict, Claude may pick one arbitrarily.
   - In a monorepo, skip other teams' CLAUDE.md files with the `claudeMdExcludes` setting.
   - Disable MCP servers you are not using with `/mcp`. Prefer CLI tools such as `gh` where they exist.
   - Use `/clear` between unrelated tasks and `/compact <focus>` within a long task.
4. **Next step**: offer to draft one specific change, for example "move the 'Release process' section (lines 120-180) into a `release` skill". Show the proposed diff and wait for the user's approval before writing anything.

If nothing is over the target and there are no always-on rules or MCP servers, say so plainly. A lean setup is a valid result.
