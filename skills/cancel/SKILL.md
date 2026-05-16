---
name: cancel
description: Cancel a running background GitHub Copilot delegation job. Trigger when the user invokes `$copilot:cancel` / `/copilot:cancel`, asks "kill that Copilot job", "stop the background Copilot run", or "cancel <job-id>". Do not trigger to cancel foreground runs — the host's own interrupt (Ctrl-C) handles those.
---

# `$copilot:cancel <job-id>` — terminate a background job

Sends `SIGTERM` to the tracked PID, then marks the job `cancelled` in its metadata file. If the process is already gone, the metadata is still updated.

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" cancel <job-id>
```

## What gets preserved

Any partial output Copilot emitted before the SIGTERM is preserved in the transcript file. Point the user at `$copilot:result <job-id>` if they want to see what was produced before the cancel.

## Quota note

Cancellation doesn't refund the premium request — once Copilot started processing the prompt, the request counts. Don't promise the user otherwise.

## Failure modes

- Unknown job id → surface the script's error.
- Process already exited → script reports this; metadata is still flipped to `cancelled`. Tell the user the job had already finished and offer `$copilot:result`.
