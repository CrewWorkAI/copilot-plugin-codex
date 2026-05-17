---
name: rescue
description: Delegate an arbitrary coding task to GitHub Copilot CLI as a subprocess. Trigger when the user invokes `$copilot:rescue` / `/copilot:rescue`, asks "ask Copilot to <task>", "delegate this to Copilot", "have Copilot try this", or wants to use a model from Copilot's lineup (Claude Sonnet/Opus/Haiku, GPT-5.x, Gemini 3 Pro) that the host doesn't natively expose. Do not trigger for code reviews — use `review` / `adversarial-review`. Do not trigger when the user wants the host agent itself to do the work.
---

# `$copilot:rescue <task>` — delegate an arbitrary task to Copilot

Hand a free-form task to Copilot CLI in non-interactive mode with all tool permissions granted. JSONL transcript is captured for later inspection via `result`.

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" rescue "<task description>" [flags]
```

Flags:

- `--model <id>` — override Copilot's default. Useful when the task fits a specific provider (Gemini for long-context, Opus for reasoning-heavy, GPT-5.x for code-gen).
- `--background` — run async; print job id immediately
- `--job-id <id>` — caller-supplied id
- `--continue` — resume Copilot's most recent session
- `--resume <session-id>` — resume a specific session

## Under the hood

```bash
copilot -p "$TASK" --allow-all-tools --output-format=json -s
```

`--allow-all-tools` is required for non-interactive mode (otherwise Copilot will hang waiting for approvals). `--output-format=json` produces JSONL — one JSON event per line, which `result` reads back. `-s` silences the stats banner.

## Foreground vs background

- **Foreground**: stream output to the user as it arrives. Use for short tasks (single-file edits, focused fixes).
- **Background**: print the job id and return immediately. Use for anything that touches more than a few files or might run more than ~60s. Confirm the job started and point the user at `status` / `result`.

If you're unsure of scope, ask the user before launching foreground.

## Resume semantics

- No `--resume` / `--continue` flag → Copilot starts a fresh session.
- `--continue` → most recent session for this user.
- `--resume <id>` → specific session by id, task id, or name (case-insensitive, exact match).

If the user trails off mid-rescue and comes back later, offer to `--continue` rather than starting fresh.

## Output handling

For foreground runs: summarize what Copilot did, what files it touched, and what's left. Surface the session id so the user can reopen interactively via `copilot --resume <id>` if they want to dig in.

For background runs: confirm the job started, show the job id, and remind the user that `status` and `result` are how they retrieve it.

## Failure modes

- `Not authenticated` → trigger `setup`.
- Sandbox/trust error → tell the user to run `copilot` interactively in this directory once.
- Quota exhausted → state this and stop. Do not silently retry.
- MCP-dependent task → Copilot CLI's `-p` mode does not load MCP servers ([github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633)). Surface this and suggest an interactive Copilot session instead.
