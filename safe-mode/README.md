# Safe Mode

A `PreToolUse` hook that checks every Bash command Claude wants to run and stops the ones you cannot undo.

| Decision | Commands |
|---|---|
| **Deny** | Recursive `rm` of `/`, `~`, `$HOME`, a home directory by full path, `.`, `..`, `*`, `.*` or a top-level system directory; `curl` or `wget` piped, substituted or `eval`/`source`d into a shell; `mkfs`, `dd` to a disk device, writes to `/dev/sd*`, fork bombs |
| **Ask** | `git push --force` (and `-f`, `--force-with-lease`, `+ref`, `--delete`, `:branch`), `git reset --hard`, `git clean -f`, `git branch -D`, `git checkout -- .`, `git checkout -f`, `git switch --discard-changes`, `git restore .`, `git stash clear/drop`, `find / -delete` or `find ~ -delete`, `chmod -R 777`, `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE TABLE` |
| **No decision** | Everything else: your normal permission rules and mode decide |

A denied command never runs, and Claude sees the reason so it can choose a safer approach. An ask shows you a permission prompt even in auto mode; in a `claude -p` run nobody can answer it, so the command does not run. Hooks run in every permission mode, including `claude -p` and bypass mode.

The rules also see through the usual wrappers: `VAR=1 rm`, `sudo -u root rm`, `env`, `timeout`, `/bin/rm`, `\rm`, `"rm"`, and quoted payloads such as `bash -c "curl ... | sh"`.

**Fails closed.** If `jq` is missing, `grep` cannot check a rule, or the hook input cannot be parsed, the script exits with code 2, which blocks the command. The hook also sets `onFailure: "block"` so a crash or timeout blocks too; that field needs Claude Code 2.1.295 or later and is silently ignored by older versions, where a crashing hook lets the command through. Behaviour checked against the [hooks reference](https://code.claude.com/docs/en/hooks) on 2026-10-25.

## Install

You need Claude Code. Pick one:

- **Try it for one session.** Download `safe-mode.zip` from https://claudekit.ai/kits/safe-mode.zip, then start Claude Code with:

  ```bash
  claude --plugin-dir ./safe-mode.zip
  ```

  `--plugin-dir` also accepts the unzipped `safe-mode/` folder.
- **Load it in every session.** Unzip it and move the `safe-mode/` folder (the one that contains `.claude-plugin/plugin.json`) into `~/.claude/skills/`. Claude Code loads it at startup unless your administrator blocks skills-directory plugins.
- **Install by name (coming soon).** When the public Claudekit kits repository is live, you will be able to run `claude plugin marketplace add <repo>` and then `claude plugin install safe-mode@claudekit-kits`. The recipe page will list the exact repository.

## Use

Nothing to run. Once the plugin is loaded, the hook checks every Bash call. Open `/hooks` to confirm it is listed under `PreToolUse`.

**Limits.** It matches command text, so it is a seatbelt, not a sandbox. A variable that holds the command or the path (`$RM -rf "$DIR"`), an encoded payload, another interpreter (`python -c`, `perl -e`), `xargs rm -rf` fed from a file, or a script that deletes files internally can slip past it. For a hard boundary, turn on the Claude Code sandbox or run unattended work in a container.

If you want a broader, maintained guard (secret and lockfile protection, a stop gate that runs your tests), Kiln Guard is the paid version from the same team: https://claudekit.ai/kits/kiln-guard/

## Permissions it needs

- Runs `hooks/guard-bash.sh` before each Bash tool call, with your user permissions, outside the Bash sandbox (as all hooks do).
- Reads only the command text from the hook input. Writes nothing, makes no network calls.
- **jq** on your `PATH`. Without it, every Bash command is blocked until you install it.

## Uninstall

- Loaded with `--plugin-dir`: start Claude Code without the flag.
- Copied into `~/.claude/skills/`: delete `~/.claude/skills/safe-mode/`.
- Installed from the marketplace: `claude plugin uninstall safe-mode@claudekit-kits`.

## How it was tested

Static checks: `bash lab/test.sh` from this folder (110 commands checked for deny, ask or no decision, including evasion attempts; exit 2 without jq, when grep fails and on invalid input). Smoke test: a real `claude -p` run with `--plugin-dir` against the fixture built by `lab/fixture.sh`, with the expectations in `lab.json`. The test level, Claude Code version and date are on the recipe page: https://claudekit.ai/recipes/safe-mode/

---

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC. MIT licensed.
