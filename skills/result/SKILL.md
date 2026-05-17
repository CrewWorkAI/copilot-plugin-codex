---
name: result
description: Read back the final transcript of a previously tracked GitHub Copilot delegation job. Trigger when the user invokes `$copilot:result` / `/copilot:result`, asks "what did that Copilot job produce", "show me the result of <job-id>", or wants to inspect a background rescue/review that has completed.
---

# `$copilot:result <job-id>` — fetch the final transcript

Reads `~/.<host>/plugins/copilot-plugin-codex/jobs/<job-id>.jsonl` and prints it.

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" result <job-id>
```

## Format

- For `rescue` jobs, the transcript is JSONL — one Copilot event per line. The final assistant message is the answer.
- For `review` / `adversarial-review`, the transcript is plain text from Copilot's `-s` output (silent mode, agent response only).

When presenting to the user, extract the meaningful tail:

- JSONL → pull the last `{"type":"assistant_message",...}` (or equivalent terminal event) and show its content. Mention if there's tool-call detail the user might want.
- Text → render directly.

Always surface the Copilot session id (visible in the JSONL or transcript header) so the user can reopen the session interactively with `copilot --resume <session-id>`.

## Edge cases

- Job still running → tell the user, point them at `$copilot:status <job-id> --wait` rather than showing a partial transcript.
- Transcript missing → could mean the job was cancelled before any output was emitted; check status metadata.
- Job failed → still show the captured output; the failure mode is usually visible in the last few lines.
