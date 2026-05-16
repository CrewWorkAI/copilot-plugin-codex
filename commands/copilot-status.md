---
description: List tracked GitHub Copilot delegation jobs for this repo.
argument-hint: [job-id] [--all] [--wait]
---

List active and recent Copilot delegation jobs.

By default, show only jobs from the current session for this repo. With `--all`, show all tracked jobs in the workspace.

Read job metadata from `~/.claude/plugins/copilot-plugin-codex/jobs/*.meta.json` and present a compact table:

| Job ID | Type | Status | Started | Model |
|---|---|---|---|---|

For a specific job-id, also show the path to its transcript and (if running) the PID.

With `--wait <job-id>`, poll the metadata file every 2 seconds until status changes from `running`. Cap the wait at 10 minutes; if still running, tell the user the job is taking long and exit.
