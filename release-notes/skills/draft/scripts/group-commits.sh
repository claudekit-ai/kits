#!/usr/bin/env bash
# Release Notes: group commits between two refs by Conventional Commit type and
# print a Markdown skeleton. Read-only; runs git read commands only.
#
# Usage: group-commits.sh [from-ref] [to-ref]
#   from-ref  Default: the latest tag reachable from to-ref, or the first commit
#   to-ref    Default: HEAD
#
# Types follow conventionalcommits.org 1.0.0: "type(scope)!: subject", and a
# "BREAKING CHANGE:" or "BREAKING-CHANGE:" footer marks a breaking change.
set -uo pipefail

die() { printf 'release-notes: %s\n' "$1" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."

from=${1:-}
to=${2:-HEAD}
for ref in "$from" "$to"; do
  case "$ref" in -*) die "refs must not start with '-'." ;; esac
done
git rev-parse --verify --quiet "$to^{commit}" >/dev/null || die "'$to' is not a commit in this repository."

if [ -z "$from" ]; then
  from=$(git describe --tags --abbrev=0 "$to" 2>/dev/null || true)
fi
if [ -n "$from" ]; then
  git rev-parse --verify --quiet "$from^{commit}" >/dev/null || die "'$from' is not a commit in this repository."
  range="$from..$to"
  label=$from
else
  range=$to
  label="the first commit"
fi

# Fields: short hash, subject, body. Unit separator between fields, record separator between commits.
log=$(git log --no-merges --format='%h%x1f%s%x1f%b%x1e' "$range") || die "git log failed for $range."

printf '%s' "$log" | awk -v RS='\036' -v FS='\037' -v from="$label" -v to="$to" '
  function add(group, line) { items[group] = items[group] "- " line "\n"; count[group]++ }
  {
    sub(/^\n+/, "", $1)
    if ($1 == "") next
    hash = $1; subject = $2; body = $3; total++
    type = ""; scope = ""; bang = 0; text = subject
    if (match(subject, /^[a-zA-Z]+(\([^)]*\))?!?: /)) {
      head = substr(subject, 1, RLENGTH - 2)
      text = substr(subject, RLENGTH + 1)
      if (head ~ /!$/) { bang = 1; head = substr(head, 1, length(head) - 1) }
      p = index(head, "(")
      if (p > 0) { type = tolower(substr(head, 1, p - 1)); scope = substr(head, p + 1, length(head) - p - 1) }
      else type = tolower(head)
    }
    entry = (scope != "" ? "**" scope ":** " : "") text " (" hash ")"
    # A breaking change is listed once, under Breaking changes.
    if (bang || body ~ /(^|\n)BREAKING[ -]CHANGE: /) { add("breaking", entry); next }
    if (type == "feat") add("feat", entry)
    else if (type == "fix") add("fix", entry)
    else if (type == "perf") add("perf", entry)
    else if (type == "revert") add("revert", entry)
    else if (type == "docs") add("docs", entry)
    else if (type == "refactor") add("refactor", entry)
    else if (type == "build" || type == "ci" || type == "chore" || type == "style" || type == "test") add("maint", entry)
    else add("other", entry)
  }
  END {
    printf "# Release notes draft: %s..%s\n\n", from, to
    printf "%d commits (merges excluded).\n", total
    n = split("breaking feat fix perf revert docs refactor other maint", order, " ")
    title["breaking"] = "Breaking changes"; title["feat"] = "Features"; title["fix"] = "Bug fixes"
    title["perf"] = "Performance"; title["revert"] = "Reverts"; title["docs"] = "Documentation"
    title["refactor"] = "Refactoring"; title["other"] = "Other changes"; title["maint"] = "Maintenance (build, ci, chore, style, test)"
    for (i = 1; i <= n; i++) {
      g = order[i]
      if (count[g] > 0) printf "\n## %s\n\n%s", title[g], items[g]
    }
    if (total == 0) printf "\nNo commits in this range.\n"
  }'
