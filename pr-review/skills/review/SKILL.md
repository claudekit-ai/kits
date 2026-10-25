---
name: review
description: Review the current branch's diff against its base branch with a fixed checklist and write the findings to REVIEW.md. Works offline; gh is optional.
argument-hint: "[base-branch]"
disable-model-invocation: true
---

# PR review

Review the committed changes on the current branch against its base, then write `REVIEW.md` at the repository root. Do not change any other file, do not commit, and do not post anything to GitHub.

## 1. Collect the diff (one command)

Run this once with the Bash tool. `$ARGUMENTS` is the base branch if the user gave one; otherwise the script picks `origin/HEAD`, `main` or `master`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/collect-diff.sh" $ARGUMENTS
```

If it exits with an error, tell the user the message and stop. If the diff is too large, review the files most likely to carry risk first (source over tests, tests over generated files) with per-file `git diff`, and list what you skipped.

Optional context: if the user asked for it and `gh` is installed and signed in, `gh pr view --json title,body` gives the PR description. Skip it otherwise; the review must not depend on the network.

## 2. Review against this checklist

For every changed file, check:

1. **Correctness**: logic errors, off-by-one, null or empty inputs, wrong conditions, unhandled branches.
2. **Error handling**: failures that are swallowed, missing awaits, resources not closed.
3. **Security**: secrets or tokens in code, injection (SQL, shell, HTML), missing auth checks, unsafe deserialisation, user input used without validation.
4. **Tests**: new or changed behaviour without tests; tests that cannot fail.
5. **Contracts**: breaking changes to public APIs, schemas, config or CLI flags without a note.
6. **Performance**: work inside loops that could run once, unbounded queries or reads.
7. **Readability**: misleading names, dead code, comments that contradict the code.
8. **Docs**: user-facing changes without README or changelog updates.

Only report what the diff shows. Quote the exact `path:line` (line numbers from the new file). Do not invent issues to fill a section; "No issues found" is a valid result for any item.

## 3. Write REVIEW.md

Use this structure:

```markdown
# Review: <branch> vs <base>

Reviewed <date>, merge base <short sha>, <n> commits, <n> files.
Verdict: Approve | Approve with nits | Request changes

## Summary
Two or three sentences on what the change does and the main risk.

## Findings
### Blocker
- `path:line`: what is wrong. Why it matters. Suggested fix.
### Major
### Minor
### Nit

## Checklist
| Check | Result |
|---|---|
| Correctness | ok / see findings / n/a |
| Error handling | ... |
| Security | ... |
| Tests | ... |
| Contracts | ... |
| Performance | ... |
| Readability | ... |
| Docs | ... |

## Not reviewed
Files skipped (generated, lockfiles, too large) and uncommitted changes.
```

Omit empty severity headings. If `REVIEW.md` already exists, overwrite it only after telling the user. Finish by printing the verdict and the count of findings per severity.
