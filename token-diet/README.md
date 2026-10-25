# Token Diet

A read-only audit of what Claude Code loads into context at the start of every session, with trims that use documented features only.

It lists your user and project `CLAUDE.md` files (including parent directories and `CLAUDE.local.md`), files they import with `@path`, rules in `.claude/rules/` that have no `paths:` and so load every time, skills, and the MCP servers in `.mcp.json`. It flags any CLAUDE.md over 200 lines, the target in Anthropic's [memory docs](https://code.claude.com/docs/en/memory), and suggests what to move: workflows into skills, area-specific instructions into path-scoped rules. It reports lines and bytes, never guessed token counts; use `/context` for real numbers.

## Install

You need Claude Code. Pick one:

- **Try it for one session.** Download `token-diet.zip` from https://claudekit.ai/kits/token-diet.zip, then start Claude Code with:

  ```bash
  claude --plugin-dir ./token-diet.zip
  ```

  `--plugin-dir` also accepts the unzipped `token-diet/` folder.
- **Load it in every session.** Unzip it and move the `token-diet/` folder (the one that contains `.claude-plugin/plugin.json`) into `~/.claude/skills/`. Claude Code loads it at startup unless your administrator blocks skills-directory plugins.
- **Install by name.** In Claude Code run `/plugin marketplace add tranquangdong/claudekit-kits`, then `/plugin install token-diet@claudekit-kits`.

## Use

```text
/token-diet:audit
```

Claude can also run it on its own when you ask why usage is climbing or how to slim CLAUDE.md. Pass a directory to audit another project: `/token-diet:audit ../api`.

The report ends with an offer to draft one change. Nothing is edited until you approve the diff.

## Permissions it needs

- **Bash**, once, to run `skills/audit/scripts/context-audit.sh`. Claude Code asks before it runs.
- Reads instruction files in the project, its parent directories and your Claude config directory. Writes nothing, makes no network calls.
- `jq` is optional; without it the MCP server list is skipped.

## Uninstall

- Loaded with `--plugin-dir`: start Claude Code without the flag.
- Copied into `~/.claude/skills/`: delete `~/.claude/skills/token-diet/`.
- Installed from the marketplace: `claude plugin uninstall token-diet@claudekit-kits`.

## How it was tested

Static checks: `bash lab/test.sh` from this folder (sizes of always-loaded files, imports, rules with and without paths, nested CLAUDE.md, skills, MCP servers, the 200-line flag, read-only). Smoke test: a real `claude -p` run with `--plugin-dir` against the fixture built by `lab/fixture.sh`, with the expectations in `lab.json`. The test level, Claude Code version and date are on the recipe page: https://claudekit.ai/recipes/token-diet/

---

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC. MIT licensed.
