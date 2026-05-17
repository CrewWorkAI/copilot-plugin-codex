---
name: copilot
description: Use when the user mentions Copilot CLI generically, asks to delegate to Copilot, or asks for a Copilot second opinion without naming a specific copilot-plugin-codex skill.
---

# Copilot delegation — router

This is the umbrella skill for delegating work from the host agent (Codex or Claude Code) to GitHub Copilot CLI. Each command has its own sub-skill at `skills/<command>/SKILL.md`. Codex exposes them as `$copilot-plugin-codex <skill>`; Claude Code exposes them as `/copilot:<command>`. This file routes free-form requests to the right one.

## Sub-skills

| Skill | Codex | Claude Code | Purpose |
|---|---|---|---|
| [`setup`](../setup/SKILL.md) | `$copilot-plugin-codex setup` | `/copilot:setup` | Verify CLI install + auth |
| [`review`](../review/SKILL.md) | `$copilot-plugin-codex review` | `/copilot:review` | Copilot review on the branch |
| [`adversarial-review`](../adversarial-review/SKILL.md) | `$copilot-plugin-codex adversarial-review` | `/copilot:adversarial-review` | Hostile-framed review |
| [`rescue`](../rescue/SKILL.md) | `$copilot-plugin-codex rescue <task>` | `/copilot:rescue <task>` | Arbitrary task delegation |
| [`status`](../status/SKILL.md) | `$copilot-plugin-codex status [job-id]` | `/copilot:status [job-id]` | List/inspect tracked jobs |
| [`result`](../result/SKILL.md) | `$copilot-plugin-codex result <job-id>` | `/copilot:result <job-id>` | Print final transcript |
| [`cancel`](../cancel/SKILL.md) | `$copilot-plugin-codex cancel <job-id>` | `/copilot:cancel <job-id>` | Terminate a background job |

## Routing rules

- "review", "check my work", "second opinion", "audit this PR" → `review`
- "red team this", "harsh review", "challenge my assumptions", "what am I missing" → `adversarial-review`
- "ask Copilot to <verb>", "have Copilot <verb>", "delegate <task>" → `rescue`
- "is that job done", "what's running", "poll the Copilot job" → `status`
- "what did Copilot say", "show me the output of <job>" → `result`
- "kill the Copilot job", "stop the background run" → `cancel`
- "is Copilot installed", "set up Copilot", first-time error → `setup`

If the user wants to use a specific model from Copilot's lineup but the task type isn't named, default to `rescue` with `--model <id>`.

## Shared invariants

All sub-skills share these properties:

- They go through `scripts/copilot-exec.sh`, which reads `HOST=codex|claude` to pick the state dir.
- They never silently retry. Auth, quota, and sandbox errors are surfaced to the user verbatim.
- Each invocation consumes one Copilot premium request.
- MCP behavior in `-p` mode is CLI-version-dependent. Copilot CLI 1.0.48 loaded the builtin GitHub MCP server during a `rescue` smoke test, but custom/additional MCP server paths are not verified by this plugin yet.

## Model selection

Copilot's default model can vary by CLI version and account. Override with `--model <id>` on any command. Available identifiers depend on the CLI version and the user's subscription; the CLI itself doesn't enforce an enum, so pass whatever model id the user names. The `/model` interactive command in Copilot is the source of truth for what their account can use.

## See also

- [`hooks/hooks.json`](../../hooks/hooks.json) — optional review-gate Stop hook (disabled by default)
- [`scripts/copilot-exec.sh`](../../scripts/copilot-exec.sh) — the wrapper every sub-skill calls
- [`commands/`](../../commands/) — Claude Code slash command definitions (one per sub-skill)
