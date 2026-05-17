---
name: status
description: Use when the user asks whether a tracked Copilot job is done, what jobs are running, or wants to poll a background job.
---

# `$copilot:status [job-id]` — list or inspect tracked jobs

Reads job metadata files from `~/.<host>/plugins/copilot-plugin-codex/jobs/` and presents them.

## Invocation

```bash
HOST=<host> bash "<plugin-root>/scripts/copilot-exec.sh" status [job-id] [--all] [--wait]
```

Set `<host>` to `codex` or `claude`. Replace `<plugin-root>` with the installed plugin root; in a local checkout, that is the repo root.

Behavior:

- No args → table of all jobs whose `cwd` matches the current directory.
- `--all` → include jobs from sibling sessions in other working directories.
- `<job-id>` → dump that one job's full metadata JSON.
- `<job-id> --wait` or `--wait <job-id>` → poll every 2s until the job leaves `running` (10-minute cap; exit 124 on timeout).

## Output handling

Don't dump raw JSON unless the user asks. Format a compact summary:

| Job ID | Type | Status | Started | Model |
|---|---|---|---|---|

For a single job, additionally show the transcript path (`<job-id>.jsonl`) and, if running, the PID. If the user wants the actual output, point them at `$copilot:result <job-id>`.

## Failure modes

- No tracked jobs → say so explicitly, don't print an empty table.
- Unknown job id → surface the script's error verbatim.
- Wait timeout → tell the user the job is still running and let them decide (continue waiting, cancel, or move on).
