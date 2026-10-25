#!/usr/bin/env bash
# Install or remove the Usage Meter status line in a Claude Code settings.json.
#
# Usage: configure.sh install|uninstall [config-dir] [--force]
#   config-dir  Directory that holds settings.json. Default: $CLAUDE_CONFIG_DIR or ~/.claude
#   --force     Replace a statusLine that some other tool configured
#
# Exit codes: 0 done, 1 bad input or missing jq, 3 another statusLine exists (rerun with --force).
# A plugin cannot set statusLine itself, so this script copies the status line
# script next to settings.json and points the statusLine entry at that copy.
set -euo pipefail

SCRIPT_NAME="usage-meter-statusline.sh"
here=$(cd "$(dirname "$0")" && pwd)

die() { printf 'usage-meter: %s\n' "$1" >&2; exit "${2:-1}"; }

action=${1:-}
shift || true
config_dir=""
force=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    -*) die "unknown option: $arg" ;;
    *) [ -z "$config_dir" ] || die "only one config-dir is allowed"; config_dir=$arg ;;
  esac
done
config_dir=${config_dir:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}

case "$action" in
  install|uninstall) ;;
  *) die "usage: configure.sh install|uninstall [config-dir] [--force]" ;;
esac

command -v jq >/dev/null 2>&1 || die "jq is required. Install it (brew install jq, apt install jq) and run this again."

mkdir -p "$config_dir"
config_dir=$(cd "$config_dir" && pwd)
settings="$config_dir/settings.json"
target="$config_dir/$SCRIPT_NAME"
# Quoted so a config path with spaces stays one word when Claude Code runs it.
status_cmd="\"$target\""

if [ -f "$settings" ]; then
  jq empty "$settings" 2>/dev/null || die "$settings is not valid JSON; fix it first, nothing was changed."
fi

current_cmd=""
[ -f "$settings" ] && current_cmd=$(jq -r '.statusLine.command // empty' "$settings")

backup=""
write_settings() {
  # $1: jq filter applied to the current settings ({} when the file is missing).
  local tmp
  tmp=$(mktemp "$config_dir/.settings.json.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  if [ -f "$settings" ]; then
    # A new backup per change, never overwriting an earlier one, so the settings
    # from before the first install stay recoverable after reinstalls.
    backup="$settings.usage-meter-$(date +%Y%m%d-%H%M%S).bak"
    [ -e "$backup" ] && backup="${backup%.bak}-$$.bak"
    cp -p "$settings" "$backup"
    jq --arg cmd "$status_cmd" "$1" "$settings" >"$tmp"
  else
    jq -n --arg cmd "$status_cmd" "{} | $1" >"$tmp"
  fi
  if [ -L "$settings" ]; then
    # A symlinked settings.json (dotfiles repo): write through the link, keep the link.
    cat "$tmp" >"$settings"
    rm -f "$tmp"
  else
    mv "$tmp" "$settings"
  fi
  trap - EXIT
  [ -z "$backup" ] || printf 'usage-meter: previous settings saved as %s\n' "$backup"
}

if [ "$action" = install ]; then
  if [ -n "$current_cmd" ] && [ "$current_cmd" != "$status_cmd" ] && [ "$force" -ne 1 ]; then
    printf 'usage-meter: %s already has a statusLine:\n  %s\n' "$settings" "$current_cmd" >&2
    printf 'Rerun with --force to replace it. Your current settings.json is backed up first.\n' >&2
    exit 3
  fi
  cp "$here/statusline.sh" "$target"
  chmod +x "$target"
  write_settings '.statusLine = {type: "command", command: $cmd}'
  printf 'usage-meter: installed. statusLine -> %s\n' "$status_cmd"
  printf 'Restart Claude Code (or send a message) to see it. Plan usage appears on Pro and Max after the first response.\n'
else
  if [ "$current_cmd" = "$status_cmd" ]; then
    write_settings 'del(.statusLine)'
    printf 'usage-meter: removed the statusLine entry from %s\n' "$settings"
  else
    printf 'usage-meter: statusLine in %s is not ours; left it unchanged.\n' "$settings"
  fi
  rm -f "$target"
  printf 'usage-meter: uninstalled.\n'
fi
