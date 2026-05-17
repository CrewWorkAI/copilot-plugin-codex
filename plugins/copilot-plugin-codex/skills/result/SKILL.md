---
name: result
description: Use when the user asks what a tracked Copilot job produced or wants the result transcript for a completed background job.
---

# `$copilot-plugin-codex result <job-id>` / `/copilot:result <job-id>` — fetch the final transcript

Reads `~/.<host>/plugins/copilot-plugin-codex/jobs/<job-id>.jsonl` and prints it.

## Invocation

```bash
HOST=<host> bash "<plugin-root>/scripts/copilot-exec.sh" result <job-id>
```

Set `<host>` to `codex` or `claude`. Replace `<plugin-root>` with the installed plugin root; in a local checkout, that is the repo root.

## Format

- For `rescue` jobs, the transcript is JSONL — one Copilot event per line. The final assistant message is the answer.
- For `review` / `adversarial-review`, the transcript is plain text from Copilot's `-s` output (silent mode, agent response only).

When presenting to the user, extract the meaningful tail:

- JSONL → pull the last `{"type":"assistant_message",...}` (or equivalent terminal event) and show its content. Mention if there's tool-call detail the user might want.
- Text → render directly.

Always surface the Copilot session id (visible in the JSONL or transcript header) so the user can reopen the session interactively with `copilot --resume <session-id>`.

## Edge cases

- Job still running → tell the user, point them at `$copilot-plugin-codex status <job-id> --wait` or `/copilot:status <job-id> --wait` rather than showing a partial transcript.
- Transcript missing → could mean the job was cancelled before any output was emitted; check status metadata.
- Job failed → still show the captured output; the failure mode is usually visible in the last few lines.
