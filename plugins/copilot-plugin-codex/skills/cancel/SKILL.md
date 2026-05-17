---
name: cancel
description: Use when the user asks to cancel, kill, or stop a tracked background Copilot job. Do not trigger for foreground runs.
---

# `$copilot:cancel <job-id>` — terminate a background job

Sends `SIGTERM` to the tracked PID, then marks the job `cancelled` in its metadata file. If the process is already gone, the metadata is still updated.

## Invocation

```bash
HOST=<host> bash "<plugin-root>/scripts/copilot-exec.sh" cancel <job-id>
```

Set `<host>` to `codex` or `claude`. Replace `<plugin-root>` with the installed plugin root; in a local checkout, that is the repo root.

## What gets preserved

Any partial output Copilot emitted before the SIGTERM is preserved in the transcript file. Point the user at `$copilot:result <job-id>` if they want to see what was produced before the cancel.

## Quota note

Cancellation doesn't refund the premium request — once Copilot started processing the prompt, the request counts. Don't promise the user otherwise.

## Failure modes

- Unknown job id → surface the script's error.
- Process already exited → script reports this; metadata is still flipped to `cancelled`. Tell the user the job had already finished and offer `$copilot:result`.
