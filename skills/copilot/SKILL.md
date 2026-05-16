---
name: copilot
description: Router for the copilot-plugin-codex delegation suite. Trigger when the user mentions Copilot CLI generically — "ask Copilot", "have Copilot look at this", "delegate to Copilot", "get a second opinion from Copilot" — without picking a specific command. This skill picks the right sub-skill (`setup`, `review`, `adversarial-review`, `rescue`, `status`, `result`, `cancel`) and hands off. Do not trigger when the user already named a specific `$copilot:<command>` — the matching sub-skill triggers directly.
---

# Copilot delegation — router

This is the umbrella skill for delegating work from the host agent (Codex or Claude Code) to GitHub Copilot CLI. Each `$copilot:<command>` has its own sub-skill at `skills/<command>/SKILL.md`. This file routes free-form requests to the right one.

## Sub-skills

| Skill | Slash command | Purpose |
|---|---|---|
| [`setup`](../setup/SKILL.md) | `$copilot:setup` / `/copilot:setup` | Verify CLI install + auth |
| [`review`](../review/SKILL.md) | `$copilot:review` / `/copilot:review` | Copilot's built-in `/review` on the branch |
| [`adversarial-review`](../adversarial-review/SKILL.md) | `$copilot:adversarial-review` | Hostile-framed review |
| [`rescue`](../rescue/SKILL.md) | `$copilot:rescue <task>` | Arbitrary task delegation |
| [`status`](../status/SKILL.md) | `$copilot:status [job-id]` | List/inspect tracked jobs |
| [`result`](../result/SKILL.md) | `$copilot:result <job-id>` | Print final transcript |
| [`cancel`](../cancel/SKILL.md) | `$copilot:cancel <job-id>` | Terminate a background job |

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
- `-p` mode does not load MCP servers ([github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633)) — sub-skills that need MCP fall back to suggesting an interactive Copilot session.

## Model selection

Copilot's default is Claude Sonnet 4.5. Override with `--model <id>` on any command. Available identifiers depend on the CLI version and the user's subscription; the CLI itself doesn't enforce an enum, so pass whatever model id the user names. The `/model` interactive command in Copilot is the source of truth for what their account can use.

## See also

- [`hooks/hooks.json`](../../hooks/hooks.json) — optional review-gate Stop hook (disabled by default)
- [`scripts/copilot-exec.sh`](../../scripts/copilot-exec.sh) — the wrapper every sub-skill calls
- [`commands/`](../../commands/) — Claude Code slash command definitions (one per sub-skill)
