---
description: Cancel a running GitHub Copilot delegation background job.
argument-hint: <job-id>
---

Send SIGTERM to a tracked background Copilot job and mark it cancelled.

Execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh cancel $ARGUMENTS
```

If the process is already gone, the metadata is still flipped to `cancelled`. Confirm to the user whether a live process was killed or the job had already exited.

Note: cancellation costs nothing extra, but any partial work Copilot did up to that point is preserved in the transcript — point the user at `/copilot:result <job-id>` if they want to see what was produced before the cancel.
