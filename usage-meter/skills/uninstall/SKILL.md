---
name: uninstall
description: Remove the Usage Meter status line from Claude Code settings and delete its script.
argument-hint: "[config-dir]"
disable-model-invocation: true
---

# Remove the Usage Meter status line

Run exactly this command with the Bash tool, appending the user's arguments if any (`$ARGUMENTS`):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/configure.sh" uninstall $ARGUMENTS
```

The script removes the `statusLine` entry only when it points at the Usage Meter script, so a status line from another tool is left alone. Report the script's output to the user. Then remind them that removing the plugin itself is a separate step: `/plugin` and uninstall, or `claude plugin uninstall usage-meter@claudekit-kits`.
