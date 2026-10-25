---
name: draft
description: Draft release notes or a CHANGELOG entry from git log between two refs, grouped by Conventional Commit type (feat, fix, perf, breaking changes). Use when the user asks for release notes, a changelog entry or "what changed since v1.2".
argument-hint: "[from-ref] [to-ref]"
---

# Draft release notes

Turn the commits between two refs into release notes a user can read. Write them to `RELEASE_NOTES.md` at the repository root. Do not edit `CHANGELOG.md`, create tags, commit or push unless the user asks for that specifically.

## 1. Group the commits (one command)

Run this once with the Bash tool. `$ARGUMENTS` holds the optional `from` and `to` refs. Without them the script uses the latest tag reachable from `HEAD` (or the first commit if there are no tags) up to `HEAD`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/group-commits.sh" $ARGUMENTS
```

If it exits with an error, show the message and stop. The output is a Markdown skeleton: commits grouped under Breaking changes, Features, Bug fixes, Performance, Reverts, Documentation, Refactoring, Other changes and Maintenance, each with its short hash.

## 2. Edit the skeleton into release notes

- Keep the groups and their order. Drop the Maintenance group unless the user asked for a full changelog.
- Rewrite each subject as a short, user-facing sentence in the past or present tense, consistently. Keep the scope in bold when there is one. Keep the short hash.
- Under **Breaking changes**, say what a user must do to upgrade when the commit body says so. If the commit gives no migration detail, write "See commit <hash> for details" instead of guessing.
- Merge commits that describe the same change. Do not invent changes, numbers or credits that are not in the commits.
- Replace the first heading with `## <version> (<today's date, YYYY-MM-DD>)` so the block can be pasted into a CHANGELOG. Use the to-ref as the version when it is a tag; when it is `HEAD` or a branch, write `Unreleased`.

## 3. Save and report

Write the result to `RELEASE_NOTES.md`. If that file already exists, tell the user and overwrite it only if they agree. Then print the notes and remind the user that nothing was tagged or published.
