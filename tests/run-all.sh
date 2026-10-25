#!/usr/bin/env bash
# Static checks for every kit: JSON parses, shell scripts pass bash -n, each
# kit's script tests pass, and `claude plugin validate` passes when the CLI exists.
# Usage: kits/tests/run-all.sh   (needs bash, jq, git)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
fail=0
step() { printf '\n== %s ==\n' "$1"; }

step "JSON parses"
while IFS= read -r f; do
  if jq empty "$f" 2>/dev/null; then echo "ok    ${f#"$root"/}"; else echo "FAIL  ${f#"$root"/}"; fail=1; fi
done < <(find "$root" -name '*.json' -type f | sort)

step "bash -n"
while IFS= read -r f; do
  if bash -n "$f"; then echo "ok    ${f#"$root"/}"; else echo "FAIL  ${f#"$root"/}"; fail=1; fi
done < <(find "$root" -name '*.sh' -type f | sort)

for kit in usage-meter safe-mode token-diet pr-review release-notes; do
  step "script tests: $kit"
  if bash "$root/$kit/lab/test.sh" >"${TMPDIR:-/tmp}/kit-test-$kit.log" 2>&1; then
    echo "ok    $(grep -c '^ok' "${TMPDIR:-/tmp}/kit-test-$kit.log") assertions"
  else
    grep -v '^ok' "${TMPDIR:-/tmp}/kit-test-$kit.log"
    fail=1
  fi
  rm -f "${TMPDIR:-/tmp}/kit-test-$kit.log"
done

step "claude plugin validate"
if command -v claude >/dev/null 2>&1; then
  for target in "$root" "$root"/usage-meter "$root"/safe-mode "$root"/token-diet "$root"/pr-review "$root"/release-notes; do
    if out=$(claude plugin validate "$target" 2>&1); then
      echo "ok    ${target#"$root"}/ $(tail -n 1 <<<"$out")"
    else
      printf 'FAIL  %s\n%s\n' "${target#"$root"}/" "$out"; fail=1
    fi
  done
else
  echo "skip  claude CLI not found"
fi

echo
[ "$fail" -eq 0 ] && echo "All static checks passed." || echo "Static checks FAILED."
exit "$fail"
