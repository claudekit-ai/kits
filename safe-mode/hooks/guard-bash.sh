#!/usr/bin/env bash
# Safe Mode: PreToolUse guard for the Bash tool.
# Denies commands you cannot undo and asks before risky ones. Prints nothing
# (exit 0) for everything else, so the normal permission flow decides.
#
# Fails closed: if jq is missing, the hook input cannot be parsed or grep cannot
# use a rule, it exits 2, which blocks the command and shows the reason to Claude.
#
# This matches command text. It is a seatbelt, not a sandbox: variables that
# hold a command or path ($RM -rf "$DIR"), encoded payloads, other interpreters
# (python -c, perl -e), xargs fed from a file, or scripts that delete files
# internally can slip past it.

command -v jq >/dev/null 2>&1 || {
  echo "safe-mode needs jq to read Bash commands; install jq (brew install jq, apt install jq). Blocking until then." >&2
  exit 2
}

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || {
  echo "safe-mode could not parse the hook input; blocking this command." >&2
  exit 2
}
[ -n "$cmd" ] || exit 0

decide() {
  jq -n --arg decision "$1" --arg reason "safe-mode: $2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $decision,
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Every rule is matched against two forms of the command: as written, and with
# quotes and backslashes removed (line continuations joined), so "rm" -rf /,
# r''m -rf /, \rm -rf / and bash -c "curl x | sh" are seen as the plain command.
norm=${cmd//\\$'\n'/ }
norm=${norm//[\"\'\\]/}
text=$cmd$'\n'$norm

# grep exits 2 when it cannot use a rule (for example a regex this grep rejects);
# block then, instead of reading it as "no match" and letting the command through.
grep_rule() {
  grep "$@" <<<"$text"
  local rc=$?
  [ "$rc" -le 1 ] || { echo "safe-mode: a rule could not be checked (grep exit $rc); blocking this command." >&2; exit 2; }
  return "$rc"
}
matches() { grep_rule -Eq -- "$1"; }
matches_i() { grep_rule -Eiq -- "$1"; }

# Start of a command: line start or a shell separator, then any mix of
# VAR=value assignments and wrappers that run the next word as a command
# (sudo -u root, env -i, timeout 5, xargs, then/do/else, !), then an optional
# directory, so /bin/rm and /usr/bin/git count too.
WRAP='(sudo|doas|command|builtin|exec|env|nohup|time|nice|ionice|timeout|xargs|then|do|else|!)'
WRAP_ARG='(-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?|[0-9][^[:space:]]*)'
ASSIGN='[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*'
S="(^|[;&|({\`]|\\\$\\()[[:space:]]*((${WRAP}([[:space:]]+${WRAP_ARG})*|${ASSIGN})[[:space:]]+)*([^[:space:];&|]*/)?"
# End of a word.
E='([[:space:];&|)`]|$)'
# An optional quote around a path.
Q="[\"']?"

# --- Deny -------------------------------------------------------------------

# Recursive delete of a broad path: /, ~, $HOME (or a user's home by absolute
# path), ., .., *, .*, the same with /* or /.* appended, or a top-level system directory.
HOMEDIR="(~|\\\$HOME|\\\$[{]HOME[}]|/(Users|home)/[^/[:space:];&|]+)"
SYSDIR="/(bin|boot|dev|etc|home|lib|lib64|opt|private|root|sbin|srv|sys|System|Library|Applications|Users|usr|var)"
BROAD="(/|/\*|/\.\*|${HOMEDIR}(/|/\*|/\.\*|/\.)?|\.|\./|\./\*|\.\.(/\.\.)*/?|\*|\.\*|${SYSDIR}/?\*?)"
RFLAG='-([a-zA-Z]*[rR][a-zA-Z]*|-recursive)'
RM_RECURSIVE="${S}rm([[:space:]]+-[^[:space:];&|]*)*[[:space:]]+${RFLAG}"
if matches "${RM_RECURSIVE}([^;&|]*[[:space:]])?${Q}${BROAD}${Q}${E}" \
  || matches "${S}rm[[:space:]]([^;&|]*[[:space:]])?${Q}${BROAD}${Q}[[:space:]]([^;&|]*[[:space:]])?${RFLAG}${E}"; then
  decide deny "Recursive delete of /, a home directory, the current or parent directory, a wildcard, or a system directory is blocked. Delete a specific subdirectory instead."
fi

# A download piped or substituted into a shell (also through sudo, env or a full path).
SHELLS='((sudo|doas|env|command|exec|nohup)([[:space:]]+-[^[:space:]]+)*[[:space:]]+)*([^[:space:];&|]*/)?(ba|z|da|k|fi)?sh'
if matches "(curl|wget)[^;&]*\|[[:space:]]*${SHELLS}${E}" \
  || matches "${SHELLS}[[:space:]]+(-c[[:space:]]+)?[\"']?(<\(|\\\$\()[[:space:]]*(curl|wget)" \
  || matches "(^|[;&|({\`[:space:]])(eval|source|\.)[[:space:]]+[\"']?(<\(|\\\$\()[[:space:]]*(curl|wget)"; then
  decide deny "Running a downloaded script without reading it is blocked. Download it to a file, read it, then run it."
fi

# Filesystem formatting, raw writes to disks, fork bombs.
if matches "${S}mkfs(\.[a-z0-9]+)?${E}" \
  || matches "${S}dd[[:space:]][^;&|]*of=/dev/(sd|hd|nvme|disk|rdisk|mmcblk|xvd)" \
  || matches ">[[:space:]]*/dev/(sd|hd|nvme|disk|rdisk|mmcblk|xvd)[a-z0-9]*" \
  || matches ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&'; then
  decide deny "Formatting or overwriting a disk device is blocked."
fi

# --- Ask --------------------------------------------------------------------

# History rewrites and discarding work in git.
GIT="${S}git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+"
if matches "${GIT}push[[:space:]]([^;&|]*[[:space:]])?(--force|--force-with-lease(=[^[:space:]]*)?|--mirror|--delete|--prune|-[a-zA-Z]*[fd][a-zA-Z]*|\+[^[:space:]]+|:[^[:space:]]+)${E}" \
  || matches "${GIT}reset[[:space:]]([^;&|]*[[:space:]])?--hard${E}" \
  || matches "${GIT}clean[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*f[a-zA-Z]*|--force)${E}" \
  || matches "${GIT}branch[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*D[a-zA-Z]*|--delete[[:space:]]+--force|--force[[:space:]]+--delete)${E}" \
  || matches "${GIT}(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.${E}" \
  || matches "${GIT}(checkout|switch)[[:space:]]([^;&|]*[[:space:]])?(-f|--force|--discard-changes)${E}" \
  || matches "${GIT}stash[[:space:]]+(clear|drop)${E}"; then
  decide ask "This git command rewrites history or discards work. Confirm it is intended."
fi

# find deleting from / or a home directory.
if matches "${S}find[[:space:]]+${Q}(/|${HOMEDIR}/?)${Q}[[:space:]]([^;&|]*[[:space:]])?(-delete|-exec[[:space:]]+([^[:space:]]*/)?rm[[:space:]])"; then
  decide ask "This find command deletes files under / or a home directory. Confirm it is intended."
fi

# World-writable recursive permissions.
if matches "${S}chmod[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*R[a-zA-Z]*|--recursive)[[:space:]]([^;&|]*[[:space:]])?(0?777|a\+rwx|ugo\+rwx)${E}" \
  || matches "${S}chmod[[:space:]]([^;&|]*[[:space:]])?(0?777|a\+rwx|ugo\+rwx)[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*R[a-zA-Z]*|--recursive)${E}"; then
  decide ask "Recursive chmod 777 makes every file world-writable. Confirm it is intended."
fi

# Destructive SQL.
if matches_i '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)[[:space:]]'; then
  decide ask "This command drops or truncates data. Confirm it is intended."
fi

exit 0
