---
description: Fetch the final output of a tracked GitHub Copilot delegation job.
argument-hint: <job-id>
---

Print the recorded transcript for a previously tracked Copilot job.

Execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh result $ARGUMENTS
```

The transcript is JSONL when the job used `--output-format=json` (rescue), otherwise plain text. If the job is still running, tell the user so and point them at `/copilot:status <job-id> --wait` rather than printing a partial transcript.

If the job id is missing or the transcript doesn't exist, surface the script's error verbatim.
