---
name: install
description: Install the Usage Meter status line (model, context %, 5-hour and weekly plan usage) into Claude Code settings.
argument-hint: "[config-dir] [--force]"
disable-model-invocation: true
---

# Install the Usage Meter status line

A plugin cannot set `statusLine` on its own, so this skill runs a bundled script that copies the status line script next to the user's `settings.json` and adds a `statusLine` entry pointing at it. Other settings are preserved, and before each change a dated backup is written next to it as `settings.json.usage-meter-<date>-<time>.bak` (earlier backups are never overwritten). If `settings.json` is a symlink, the link is kept and its target is updated.

Arguments from the user: `$ARGUMENTS` (optional config directory, optional `--force`). With no config directory the script uses `$CLAUDE_CONFIG_DIR` or `~/.claude`.

Steps:

1. Run exactly this command with the Bash tool, appending the user's arguments if any:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/configure.sh" install $ARGUMENTS
   ```

2. Read the exit code and output:
   - `0`: tell the user it is installed and that the 5-hour and weekly numbers appear only on Pro and Max plans, after the first response in a session.
   - `3`: another status line is already configured. Show the user the existing command and ask whether to replace it. Only if they say yes, rerun with `--force` added.
   - `1`: show the error (usually missing `jq` or invalid JSON in settings.json) and stop. Do not edit settings.json by hand.
3. Test the installed script with this sample input and show the user the line it prints:

   ```bash
   echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":8},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},"seven_day":{"used_percentage":41.2,"resets_at":1738857600}}}' | bash "<config-dir>/usage-meter-statusline.sh"
   ```

   Replace `<config-dir>` with the directory the install step printed.

Do not change any other setting. Do not run any other command.
