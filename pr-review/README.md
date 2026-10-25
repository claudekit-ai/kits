# PR Review

Reviews the committed changes on your current branch against its base and writes the findings to `REVIEW.md`: a verdict, findings by severity with `path:line`, and an eight-point checklist (correctness, error handling, security, tests, contracts, performance, readability, docs).

It works offline: the diff comes from local `git`. `gh` is optional and used only if you ask for the PR description. It never commits, pushes or posts comments.

## Install

You need Claude Code. Pick one:

- **Try it for one session.** Download `pr-review.zip` from https://claudekit.ai/kits/pr-review.zip, then start Claude Code with:

  ```bash
  claude --plugin-dir ./pr-review.zip
  ```

  `--plugin-dir` also accepts the unzipped `pr-review/` folder.
- **Load it in every session.** Unzip it and move the `pr-review/` folder (the one that contains `.claude-plugin/plugin.json`) into `~/.claude/skills/`. Claude Code loads it at startup unless your administrator blocks skills-directory plugins.
- **Install by name.** In Claude Code run `/plugin marketplace add tranquangdong/claudekit-kits`, then `/plugin install pr-review@claudekit-kits`.

## Use

```text
/pr-review:review          # base: origin/HEAD, then main, then master
/pr-review:review develop  # explicit base
```

Diffs over 3,000 lines switch to a file list, and Claude reviews the riskiest files one by one and lists what it skipped. Uncommitted changes are reported but not reviewed. Treat the review as a second pair of eyes, not a substitute for your own.

## Permissions it needs

- **Bash**, to run `skills/review/scripts/collect-diff.sh` (read-only `git` commands) and, if needed, per-file `git diff`.
- **Write**, for `REVIEW.md` at the repository root. Claude asks before overwriting an existing one.
- No network access unless you ask it to use `gh`.

## Uninstall

- Delete any `REVIEW.md` files you no longer need.
- Loaded with `--plugin-dir`: start Claude Code without the flag.
- Copied into `~/.claude/skills/`: delete `~/.claude/skills/pr-review/`.
- Installed from the marketplace: `claude plugin uninstall pr-review@claudekit-kits`.

## How it was tested

Static checks: `bash lab/test.sh` from this folder (base detection, commits, diffstat, diff, size limit, uncommitted changes, bad input). Smoke test: a real `claude -p` run with `--plugin-dir` against the fixture built by `lab/fixture.sh`, with the expectations in `lab.json`. The test level, Claude Code version and date are on the recipe page: https://claudekit.ai/recipes/pr-review/

---

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC. MIT licensed.
