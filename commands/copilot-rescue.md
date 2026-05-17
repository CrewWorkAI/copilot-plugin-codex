---
description: Delegate a coding task to GitHub Copilot CLI. Useful for second opinions or when Copilot's model lineup includes the right tool for the job.
argument-hint: <task description> [--background] [--model <model>] [--resume]
---

Hand a task to GitHub Copilot CLI via the copilot-plugin-codex wrapper.

Extract the task description from `$ARGUMENTS` (everything before the first `--` flag). Then execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh rescue "$TASK" $FLAGS
```

For long-running tasks, suggest `--background` and explain that the user can check status with `/copilot:status` and pull the final output with `/copilot:result`.

When the task completes:
- For foreground runs: summarize what Copilot did, what files it touched, and what's left.
- For background runs: confirm the job started and show the job ID.

Do not silently retry on failure. Surface auth, quota, and sandbox errors verbatim.
