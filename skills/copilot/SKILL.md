---
name: copilot
description: Use this skill whenever the user wants to delegate a coding task, code review, or background workflow to GitHub Copilot CLI from inside another agent (Codex or Claude Code). Triggers include any mention of `$copilot:` or `/copilot:` slash commands, phrases like "ask Copilot to...", "have Copilot review...", "delegate this to Copilot", "second opinion from Copilot", or any explicit request to route work through Copilot's model lineup (Claude Sonnet 4.6, GPT-5.3-Codex, Gemini 3 Pro, etc.). Also use when the user wants to leverage Copilot's multi-provider model selection for a task that benefits from a specific provider.
---

# Copilot delegation skill

This skill lets the host agent (Codex or Claude Code) delegate work to GitHub Copilot CLI as a subprocess. Copilot CLI's headless `--prompt` mode is the substrate; everything else is structured invocation, output parsing, and job tracking.

## When to invoke

Trigger this skill for any of:

- Explicit slash command: `$copilot:review`, `$copilot:rescue`, `$copilot:status`, `$copilot:result`, `$copilot:cancel`, `$copilot:setup` (Codex) or `/copilot:review` etc. (Claude Code)
- The user says "ask Copilot", "have Copilot look at this", "delegate to Copilot", "get a second opinion from Copilot"
- The user wants to use a specific model that Copilot exposes but the host doesn't (e.g. running Gemini 3 Pro for a task from inside Codex)
- The user wants Copilot's built-in `/review` agent specifically rather than the host's review

Do **not** trigger when the user wants the host agent itself to do the work — this is purely for delegation.

## Setup check (run before first use)

The setup command verifies Copilot CLI is installed and authenticated. Run it explicitly when:

- The user invokes `$copilot:setup` / `/copilot:setup`
- Any other command fails with a "copilot not found" or auth error

The check itself:

```bash
copilot --version 2>/dev/null || echo "MISSING"
```

If missing, offer to install via:

```bash
npm install -g @github/copilot
```

After install, the user must run `copilot` once interactively in a trusted directory to authenticate via `gh auth login` (Copilot CLI piggybacks on `gh` credentials).

## Core invocation pattern

All delegation goes through `scripts/copilot-exec.sh`, which wraps `copilot -p` with sane defaults. The script lives at `${PLUGIN_ROOT}/scripts/copilot-exec.sh` and accepts:

```
copilot-exec.sh <command-type> <prompt> [--model <model>] [--background] [--job-id <id>]
```

Command types:

- `review` — invokes Copilot's built-in `/review` slash command on current branch vs `main`
- `adversarial-review` — same as review but with a sharper prompt that asks Copilot to challenge assumptions
- `rescue` — generic task delegation with `--allow-all-tools`
- `setup` — runs the setup check

## Slash command reference

### `$copilot:review` / `/copilot:review`

Runs a standard Copilot code review on the current branch vs `main` (or the ref passed via `--base`).

```bash
copilot -p '/review the changes on this branch compared to main. Focus on bugs and security issues.' \
  -s --allow-tool='shell(git:*)'
```

Flags: `--base <ref>`, `--background`, `--wait`, `--model <model>`.

### `$copilot:adversarial-review`

Same surface as `$copilot:review` but with a system prompt prepended that frames Copilot as a hostile reviewer challenging the host agent's work.

### `$copilot:rescue <task>`

Delegates an arbitrary task to Copilot:

```bash
copilot -p "$TASK" --allow-all-tools --output-format=json -s
```

Flags: `--background`, `--wait`, `--resume <session-id>`, `--fresh`, `--model <model>`.

If the user omits `--resume` and `--fresh`, offer to continue the most recent rescue thread for this repo. Resume mapping uses Copilot's `--continue` flag with the stored session ID.

### `$copilot:status [job-id]`

Lists tracked jobs in `~/.<host>/plugins/copilot-plugin-codex/jobs/`. If `--all` is passed, includes jobs from sibling sessions in the same workspace.

### `$copilot:result [job-id]`

Reads the JSONL transcript at `~/.<host>/plugins/copilot-plugin-codex/jobs/<job-id>.jsonl` and extracts the final assistant message. Includes the Copilot session ID so the user can reopen via `copilot --resume <session-id>` directly.

### `$copilot:cancel <job-id>`

Sends SIGTERM to the tracked PID, marks the job as cancelled in the metadata file. If the process is already gone, just updates the metadata.

## Model selection

Copilot's default is Claude Sonnet 4.5. Override via `--model`:

- `claude-sonnet-4.6` — Anthropic, balanced default
- `claude-opus-4.6` — Anthropic, heavier reasoning
- `claude-haiku-4.5` — Anthropic, fast
- `gpt-5.3-codex` — OpenAI, codex-tuned
- `gemini-3-pro` — Google

If the user asks for "best model for X", prefer the routing logic in the sibling `model-router` plugin rather than hard-coding choices here.

## Known limitations to surface to the user

1. **MCP servers do not run in `--prompt` mode.** [github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633). If the task requires MCP tooling, fall back to suggesting an interactive Copilot session.
2. **Copilot CLI requires a Git repository** for some features (remote access, certain agent flows). `$copilot:setup` checks for this and surfaces a clear error.
3. **Each Copilot invocation consumes one premium request** from the user's Copilot subscription quota.

## Failure handling

If `copilot -p` exits non-zero:

- Auth error (`Not authenticated`) → run setup check, suggest `copilot /login`
- Quota exhausted → surface clearly, do not retry
- Sandbox/trust error → tell the user to start an interactive `copilot` session in the directory once to establish trust, then retry
- Generic failure → return the stderr verbatim to the host agent so the user can see it

Never silently retry. Failed delegations are visible to the user.

## See also

- [`hooks/hooks.json`](../../hooks/hooks.json) — Codex Stop hook for optional Copilot-review-gate
- [`scripts/copilot-exec.sh`](../../scripts/copilot-exec.sh) — the invocation wrapper
- [`commands/`](../../commands/) — Claude Code slash command definitions
