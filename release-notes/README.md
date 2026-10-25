# Release Notes

Drafts release notes from `git log` between two refs. Commits are grouped by [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) type, with breaking changes (`feat!:` or a `BREAKING CHANGE:` footer) listed first, then features, bug fixes, performance and the rest. Claude rewrites each subject as a readable line, keeps the short hash, and saves the result to `RELEASE_NOTES.md`, ready to paste into a CHANGELOG.

Commits that do not follow the convention still appear, under "Other changes". It never tags, commits, edits `CHANGELOG.md` or publishes anything unless you ask.

## Install

You need Claude Code. Pick one:

- **Try it for one session.** Download `release-notes.zip` from https://claudekit.ai/kits/release-notes.zip, then start Claude Code with:

  ```bash
  claude --plugin-dir ./release-notes.zip
  ```

  `--plugin-dir` also accepts the unzipped `release-notes/` folder.
- **Load it in every session.** Unzip it and move the `release-notes/` folder (the one that contains `.claude-plugin/plugin.json`) into `~/.claude/skills/`. Claude Code loads it at startup unless your administrator blocks skills-directory plugins.
- **Install by name (coming soon).** When the public Claudekit kits repository is live, you will be able to run `claude plugin marketplace add <repo>` and then `claude plugin install release-notes@claudekit-kits`. The recipe page will list the exact repository.

## Use

```text
/release-notes:draft                 # latest tag..HEAD
/release-notes:draft v1.2.0 v1.3.0   # explicit range
```

Claude can also start it on its own when you ask "what changed since v1.2?". Merge commits are left out.

## Permissions it needs

- **Bash**, to run `skills/draft/scripts/group-commits.sh` (read-only `git log`).
- **Write**, for `RELEASE_NOTES.md`. Claude asks before overwriting an existing one.
- No network access.

## Uninstall

- Delete `RELEASE_NOTES.md` if you no longer need it.
- Loaded with `--plugin-dir`: start Claude Code without the flag.
- Copied into `~/.claude/skills/`: delete `~/.claude/skills/release-notes/`.
- Installed from the marketplace: `claude plugin uninstall release-notes@claudekit-kits`.

## How it was tested

Static checks: `bash lab/test.sh` from this folder (grouping by type and scope, breaking changes from `!` and the footer, default range from the latest tag, bad refs). Smoke test: a real `claude -p` run with `--plugin-dir` against the fixture built by `lab/fixture.sh`, with the expectations in `lab.json`. The test level, Claude Code version and date are on the recipe page: https://claudekit.ai/recipes/release-notes/

---

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC. MIT licensed.
