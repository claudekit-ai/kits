# Usage Meter

A Claude Code status line that shows the model, how full the context window is, and how much of your 5-hour and weekly plan limits you have used:

```text
[Opus] ctx 8% | 5h 23% (resets 16:00) | week 41% (resets Thu 16:00)
```

Each percentage turns yellow from 50% and red from 80%. The script runs locally on the JSON Claude Code already sends to status lines, so it never calls the model and costs nothing.

**Plan note.** The 5-hour and weekly numbers come from the `rate_limits` field, which Claude Code sends only to claude.ai **Pro and Max** subscribers (or behind a Claude apps gateway with spend limits), and only after the first response in a session. With an API key you see the model and context only. Field names checked against the [status line docs](https://code.claude.com/docs/en/statusline) on 2026-10-25.

## Install

You need Claude Code. Pick one:

- **Try it for one session.** Download `usage-meter.zip` from https://claudekit.ai/kits/usage-meter.zip, then start Claude Code with:

  ```bash
  claude --plugin-dir ./usage-meter.zip
  ```

  `--plugin-dir` also accepts the unzipped `usage-meter/` folder.
- **Load it in every session.** Unzip it and move the `usage-meter/` folder (the one that contains `.claude-plugin/plugin.json`) into `~/.claude/skills/`. Claude Code loads it at startup unless your administrator blocks skills-directory plugins.
- **Install by name.** In Claude Code run `/plugin marketplace add claudekit-ai/kits`, then `/plugin install usage-meter@claudekit`.

## Use

A plugin cannot set `statusLine` itself (plugin settings accept only `agent` and `subagentStatusLine`), so the kit ships a one-time setup skill:

```text
/usage-meter:install
```

It copies the script to `~/.claude/usage-meter-statusline.sh` (or `$CLAUDE_CONFIG_DIR`), adds a `statusLine` entry to `settings.json`, keeps every other setting, and saves a dated backup such as `settings.json.usage-meter-20261025-153000.bak` before each change (it never overwrites an earlier backup, and a symlinked `settings.json` stays a symlink). If another status line is already configured it stops and asks; rerun with `/usage-meter:install --force` to replace it. Restart Claude Code or send a message to see the line.

Prefer to do it by hand? Run `bash scripts/configure.sh install` from this folder, or copy `scripts/statusline.sh` anywhere and point `statusLine.command` at it.

## Permissions it needs

- **Bash**, once, to run `scripts/configure.sh` during install or uninstall. Claude Code asks before it runs.
- **Writes** to `settings.json` and one script file in your Claude config directory. Nothing else.
- **jq 1.6 or later** on your `PATH` (`brew install jq`, `apt install jq`). Without it the status line prints `[usage-meter: install jq]`.
- No network access, no hooks, no MCP servers.

## Uninstall

- Run `/usage-meter:uninstall` first. It removes the `statusLine` entry only if it points at this kit's script, and deletes the script.
- Loaded with `--plugin-dir`: start Claude Code without the flag.
- Copied into `~/.claude/skills/`: delete `~/.claude/skills/usage-meter/`.
- Installed from the marketplace: `claude plugin uninstall usage-meter@claudekit`.

## How it was tested

Static checks: `bash lab/test.sh` from this folder (status line output for sample inputs and the settings.json install and uninstall flow). Smoke test: a real `claude -p` run with `--plugin-dir` against the fixture built by `lab/fixture.sh`, with the expectations in `lab.json`. The test level, Claude Code version and date are on the recipe page: https://claudekit.ai/recipes/usage-meter/

---

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC. MIT licensed.
