# copilot-plugin-codex

Delegate work from **Codex** or **Claude Code** to **GitHub Copilot CLI**.

A modified fork of [`sendbird/cc-plugin-codex`](https://github.com/sendbird/cc-plugin-codex), retargeted at GitHub Copilot CLI as the worker and extended to support both Codex and Claude Code as hosts from a single codebase. Layout, command surface, and the per-command skill structure are inherited from the upstream; the wrapper script, manifests, and skill bodies are rewritten for Copilot. See [`NOTICE`](./NOTICE) for full attribution.

Companion to the existing cross-CLI delegation plugins:

| Plugin | Host | Worker |
|---|---|---|
| [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) | Claude Code | Codex |
| [`sendbird/cc-plugin-codex`](https://github.com/sendbird/cc-plugin-codex) | Codex | Claude Code |
| **`CrewWorkAI/copilot-plugin-codex` (this)** | **Codex or Claude Code** | **Copilot** |

## Why Copilot

Copilot CLI is the only major coding agent CLI that lets you switch between Anthropic, OpenAI, and Google models mid-session (Claude Sonnet/Opus/Haiku 4.5–4.6, GPT-5.3-Codex, Gemini 3 Pro). From inside Codex or Claude Code, that turns Copilot into a useful "use the right model for this task" subprocess — including models the host doesn't natively expose.

## Install

### Codex

```bash
codex plugin marketplace add CrewWorkAI/copilot-plugin-codex
codex plugin install copilot-plugin-codex@copilot-plugin-codex
```

Then in a thread:

```
$copilot:setup
$copilot:review
$copilot:rescue <task description>
```

### Claude Code

```bash
/plugin marketplace add CrewWorkAI/copilot-plugin-codex
/plugin install copilot-plugin-codex@copilot-plugin-codex
```

Then:

```
/copilot:setup
/copilot:review
/copilot:rescue <task description>
```

## Prerequisites

- Node.js 18+
- Python 3 (required by `scripts/validate.sh` and used as a JSON fallback by the runtime wrapper)
- `jq` recommended for job metadata reads; without it, the runtime wrapper falls back to Python 3
- GitHub Copilot CLI: `npm install -g @github/copilot` (run `$copilot:setup` to verify or get install instructions)
- A GitHub Copilot subscription (Pro, Pro+, Business, or Enterprise)
- `gh auth login` completed at least once

## Commands

| Codex | Claude Code | Purpose |
|---|---|---|
| `$copilot:setup` | `/copilot:setup` | Verify Copilot CLI install & auth |
| `$copilot:review` | `/copilot:review` | Copilot's `/review` on current branch |
| `$copilot:adversarial-review` | `/copilot:adversarial-review` | Hostile-reviewer-framed review |
| `$copilot:rescue <task>` | `/copilot:rescue <task>` | Delegate an arbitrary task |
| `$copilot:status [job-id]` | `/copilot:status [job-id]` | List/inspect tracked jobs |
| `$copilot:result <job-id>` | `/copilot:result <job-id>` | Get final output of a job |
| `$copilot:cancel <job-id>` | `/copilot:cancel <job-id>` | Cancel a background job |

All commands accept `--model <model-id>` to override Copilot's default (currently Claude Sonnet 4.5). Full model list in [`skills/copilot/SKILL.md`](./skills/copilot/SKILL.md).

## Architecture

This plugin targets both Codex and Claude Code from one codebase:

```
copilot-plugin-codex/
├── .codex-plugin/plugin.json        ← Codex reads this
├── .claude-plugin/
│   ├── plugin.json                  ← Claude Code reads this
│   └── marketplace.json             ← Claude Code marketplace catalog (one-entry)
├── .agents/plugins/marketplace.json ← Codex marketplace catalog (one-entry)
├── skills/copilot/SKILL.md          ← Canonical instructions (both hosts read this)
├── commands/copilot-*.md            ← Claude Code slash command definitions
├── hooks/hooks.json                 ← Codex hooks (review gate, disabled by default)
└── scripts/
    ├── copilot-exec.sh              ← The `copilot -p` wrapper
    └── setup.sh                     ← Install/verify Copilot CLI
```

`scripts/copilot-exec.sh` reads `HOST=codex` or `HOST=claude` from the environment to pick the right state directory (`~/.codex/plugins/...` vs `~/.claude/plugins/...`). Both hosts shell out to the same script.

## Known limitations

1. **MCP servers don't run in `copilot -p` mode** ([github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633)). If a delegated task needs MCP tooling, the plugin will surface this and suggest an interactive Copilot session instead.
2. **Some Copilot features require a Git repository** (notably `/review` and remote access). `$copilot:setup` checks for this.
3. **Each invocation = one Copilot premium request.** Background loops with the review hook enabled can drain quota fast — the hook is disabled by default.

## Status

Alpha. Manifests, scripts, and slash commands are wired up and `bash scripts/validate.sh` passes; end-to-end install + invocation against real Copilot CLI hasn't been smoke-tested yet. See [`CLAUDE.md`](./CLAUDE.md) for known gaps and the recommended next-task list.

## License

MIT for original contributions. See [`LICENSE`](./LICENSE). Portions derived from `sendbird/cc-plugin-codex` (Apache 2.0) and, transitively, `openai/codex-plugin-cc` (Apache 2.0) — see [`NOTICE`](./NOTICE).
