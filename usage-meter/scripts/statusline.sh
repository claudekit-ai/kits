#!/usr/bin/env bash
# Usage Meter status line: model, context use and plan usage limits.
# Claude Code pipes session JSON to stdin; this prints one line. Needs jq 1.6+.
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf '[usage-meter: install jq]\n'
  exit 0
fi

# One jq call. Absent fields become empty strings, and "|" or control characters
# in the model name become spaces, so the columns never shift.
IFS='|' read -r model ctx five five_reset week week_reset <<<"$(
  printf '%s' "$input" | jq -r '
    def pct(p): if p == null then "" else (p | floor | tostring) end;
    def at(t; fmt): if t == null then "" else (t | strflocaltime(fmt)) end;
    [ (.model.display_name // "Claude" | tostring | gsub("[|[:cntrl:]]"; " ")),
      pct(.context_window.used_percentage),
      pct(.rate_limits.five_hour.used_percentage),
      at(.rate_limits.five_hour.resets_at; "%H:%M"),
      pct(.rate_limits.seven_day.used_percentage),
      at(.rate_limits.seven_day.resets_at; "%a %H:%M")
    ] | join("|")' 2>/dev/null
)"

# Green under 50%, yellow under 80%, red from 80%.
paint() {
  local color=32
  if [ "$1" -ge 80 ]; then color=31; elif [ "$1" -ge 50 ]; then color=33; fi
  printf '\033[%sm%s%%\033[0m' "$color" "$1"
}

line="[${model:-Claude}]"
[ -n "$ctx" ] && line+=" ctx $(paint "$ctx")"
[ -n "$five" ] && line+=" | 5h $(paint "$five")${five_reset:+ (resets $five_reset)}"
[ -n "$week" ] && line+=" | week $(paint "$week")${week_reset:+ (resets $week_reset)}"
printf '%s\n' "$line"
