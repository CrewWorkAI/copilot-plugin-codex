---
description: List tracked GitHub Copilot delegation jobs for this repo.
argument-hint: [job-id] [--all] [--wait]
---

List active and recent Copilot delegation jobs.

Execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh status $ARGUMENTS
```

By default, only jobs whose `cwd` matches the current directory are shown. `--all` includes every tracked job in `~/.claude/plugins/copilot-plugin-codex/jobs/`.

For a specific job-id, the script dumps the full metadata JSON. With `--wait`, it polls until the job leaves `running` (10-minute cap, exit 124 on timeout).

After the script returns, render the metadata as a compact summary for the user — don't dump raw JSON unless they ask.
