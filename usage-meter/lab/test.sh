#!/usr/bin/env bash
# Static test for usage-meter: the status line output for sample inputs (field
# names from the statusline docs) and the settings.json install/uninstall flow.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
kit=$(cd "$here/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }
strip() { sed $'s/\033\\[[0-9;]*m//g'; }

# --- Status line output -------------------------------------------------------
line=$(echo '{"model":{"id":"claude-opus-5-5","display_name":"Opus"},"context_window":{"used_percentage":8},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},"seven_day":{"used_percentage":41.2,"resets_at":1738857600}}}' \
  | TZ=UTC bash "$kit/scripts/statusline.sh" | strip)
[ "$line" = "[Opus] ctx 8% | 5h 23% (resets 16:00) | week 41% (resets Thu 16:00)" ] && ok "Pro/Max sample: $line" || bad "Pro/Max sample: $line"

line=$(echo '{"model":{"display_name":"Sonnet"}}' | bash "$kit/scripts/statusline.sh" | strip)
[ "$line" = "[Sonnet]" ] && ok "API key (no rate_limits): $line" || bad "API key: $line"

line=$(echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":null},"rate_limits":{"seven_day":{"used_percentage":90,"resets_at":1738857600}}}' \
  | TZ=UTC bash "$kit/scripts/statusline.sh" | strip)
[ "$line" = "[Opus] | week 90% (resets Thu 16:00)" ] && ok "weekly window only: $line" || bad "weekly only: $line"

raw=$(echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":85}}' | bash "$kit/scripts/statusline.sh")
grep -q $'\033\\[31m85%' <<<"$raw" && ok "red from 80%" || bad "red from 80%: $raw"
raw=$(echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":55}}' | bash "$kit/scripts/statusline.sh")
grep -q $'\033\\[33m55%' <<<"$raw" && ok "yellow from 50%" || bad "yellow from 50%: $raw"

line=$(echo '{"model":{"display_name":"Evil|Name"},"context_window":{"used_percentage":8}}' | bash "$kit/scripts/statusline.sh" | strip)
[ "$line" = "[Evil Name] ctx 8%" ] && ok "pipe in model name does not shift columns" || bad "pipe in name: $line"

line=$(echo 'garbage' | bash "$kit/scripts/statusline.sh" | strip)
[ "$line" = "[Claude]" ] && ok "invalid input prints a fallback" || bad "invalid input: $line"

# --- settings.json install / uninstall --------------------------------------
cfg="$tmp/cfg"
mkdir -p "$cfg"
printf '{"model":"sonnet","permissions":{"deny":["Read(./.env)"]}}\n' >"$cfg/settings.json"

bash "$kit/scripts/configure.sh" install "$cfg" >/dev/null 2>&1 && ok "install exit 0" || bad "install failed"
cmd=$(jq -r '.statusLine.command' "$cfg/settings.json")
[ "$cmd" = "\"$cfg/usage-meter-statusline.sh\"" ] && ok "statusLine points at the copied script" || bad "statusLine command: $cmd"
[ "$(jq -r '.statusLine.type' "$cfg/settings.json")" = command ] && ok "statusLine type is command" || bad "statusLine type"
[ "$(jq -r '.model' "$cfg/settings.json")" = sonnet ] && [ "$(jq -r '.permissions.deny[0]' "$cfg/settings.json")" = "Read(./.env)" ] \
  && ok "other settings preserved" || bad "other settings lost"
[ -x "$cfg/usage-meter-statusline.sh" ] && ok "script copied and executable" || bad "script not copied"
bak=$(ls "$cfg"/settings.json.usage-meter-*.bak 2>/dev/null | head -n 1)
[ -n "$bak" ] && [ "$(jq -r 'has("statusLine")' "$bak")" = false ] && [ "$(jq -r '.model' "$bak")" = sonnet ] && ok "backup holds the settings from before the install" || bad "no backup of the original settings"
# The configured command runs through a shell exactly as Claude Code would run it.
line=$(echo '{"model":{"display_name":"Opus"}}' | sh -c "$cmd" | strip)
[ "$line" = "[Opus]" ] && ok "configured command runs" || bad "configured command output: $line"

bash "$kit/scripts/configure.sh" install "$cfg" >/dev/null 2>&1 && ok "reinstall is idempotent" || bad "reinstall failed"
[ "$(jq -r 'has("statusLine")' "$bak")" = false ] && ok "reinstall does not overwrite the first backup" || bad "first backup was overwritten"

other="$tmp/other"
mkdir -p "$other"
printf '{"statusLine":{"type":"command","command":"~/my-line.sh"}}\n' >"$other/settings.json"
bash "$kit/scripts/configure.sh" install "$other" >/dev/null 2>&1
code=$?
[ "$code" -eq 3 ] && ok "refuses to replace another statusLine (exit 3)" || bad "foreign statusLine exit $code"
[ "$(jq -r '.statusLine.command' "$other/settings.json")" = "~/my-line.sh" ] && ok "foreign statusLine untouched" || bad "foreign statusLine changed"
bash "$kit/scripts/configure.sh" install "$other" --force >/dev/null 2>&1 && \
  [ "$(jq -r '.statusLine.command' "$other/settings.json")" = "\"$other/usage-meter-statusline.sh\"" ] && ok "--force replaces it" || bad "--force failed"

bash "$kit/scripts/configure.sh" uninstall "$cfg" >/dev/null 2>&1 && ok "uninstall exit 0" || bad "uninstall failed"
[ "$(jq -r 'has("statusLine")' "$cfg/settings.json")" = false ] && ok "statusLine removed" || bad "statusLine still present"
[ "$(jq -r '.model' "$cfg/settings.json")" = sonnet ] && ok "other settings kept after uninstall" || bad "settings lost on uninstall"
[ ! -e "$cfg/usage-meter-statusline.sh" ] && ok "script removed" || bad "script left behind"

# A symlinked settings.json (dotfiles) stays a symlink and the target gets the change.
linked="$tmp/linked"
mkdir -p "$linked" "$tmp/dotfiles"
printf '{"model":"opus"}\n' >"$tmp/dotfiles/settings.json"
ln -s "$tmp/dotfiles/settings.json" "$linked/settings.json"
bash "$kit/scripts/configure.sh" install "$linked" >/dev/null 2>&1
[ -L "$linked/settings.json" ] && [ "$(jq -r '.statusLine.type' "$tmp/dotfiles/settings.json")" = command ] && [ "$(jq -r '.model' "$tmp/dotfiles/settings.json")" = opus ] \
  && ok "symlinked settings.json stays a symlink and its target is updated" || bad "symlinked settings.json replaced or not updated"

fresh="$tmp/fresh dir"
bash "$kit/scripts/configure.sh" install "$fresh" >/dev/null 2>&1 && [ "$(jq -r '.statusLine.type' "$fresh/settings.json")" = command ] \
  && ok "creates settings.json in a new directory with a space in its path" || bad "fresh install failed"
line=$(echo '{"model":{"display_name":"Opus"}}' | sh -c "$(jq -r '.statusLine.command' "$fresh/settings.json")" | strip)
[ "$line" = "[Opus]" ] && ok "quoted command works with a space in the path" || bad "space path output: $line"

broken="$tmp/broken"
mkdir -p "$broken"
printf '{not json' >"$broken/settings.json"
bash "$kit/scripts/configure.sh" install "$broken" >/dev/null 2>&1
code=$?
[ "$code" -eq 1 ] && [ "$(cat "$broken/settings.json")" = "{not json" ] && ok "invalid settings.json left unchanged (exit 1)" || bad "invalid settings exit $code"

bash "$kit/scripts/configure.sh" bogus >/dev/null 2>&1
[ $? -eq 1 ] && ok "unknown action exit 1" || bad "unknown action"

exit "$fail"
