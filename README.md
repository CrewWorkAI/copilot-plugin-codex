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

Copilot CLI can switch between model providers from the same session, depending on the user's subscription and CLI version. From inside Codex or Claude Code, that turns Copilot into a useful "use the right model for this task" subprocess — including models the host may not natively expose. Use Copilot's interactive `/model` command as the source of truth for the models available to an account.

## Install

### Codex

```bash
codex plugin marketplace add CrewWorkAI/copilot-plugin-codex
```

Current Codex CLI versions register the marketplace through the command above. Then install or enable `copilot-plugin-codex@copilot-plugin-codex` from Codex's plugin marketplace UI and start a new thread:

```
$copilot-plugin-codex setup
$copilot-plugin-codex review
$copilot-plugin-codex rescue <task description>
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
- GitHub Copilot CLI: `npm install -g @github/copilot` (run `$copilot-plugin-codex setup` to verify or get install instructions)
- A GitHub Copilot subscription (Pro, Pro+, Business, or Enterprise)
- Authentication via `copilot login`, `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`, or `gh auth login`

## Commands

| Codex | Claude Code | Purpose |
|---|---|---|
| `$copilot-plugin-codex setup` | `/copilot:setup` | Verify Copilot CLI install & auth |
| `$copilot-plugin-codex review` | `/copilot:review` | Copilot review on current branch |
| `$copilot-plugin-codex adversarial-review` | `/copilot:adversarial-review` | Hostile-reviewer-framed review |
| `$copilot-plugin-codex rescue <task>` | `/copilot:rescue <task>` | Delegate an arbitrary task |
| `$copilot-plugin-codex status [job-id]` | `/copilot:status [job-id]` | List/inspect tracked jobs |
| `$copilot-plugin-codex result <job-id>` | `/copilot:result <job-id>` | Get final output of a job |
| `$copilot-plugin-codex cancel <job-id>` | `/copilot:cancel <job-id>` | Cancel a background job |

All commands accept `--model <model-id>` to override Copilot's current default. The available identifiers depend on the installed Copilot CLI and the user's subscription; run `/model` in an interactive Copilot session for the authoritative list.

## Architecture

This plugin targets both Codex and Claude Code from one codebase:

```
copilot-plugin-codex/
├── .agents/plugins/marketplace.json           ← Codex marketplace catalog (one-entry)
├── .claude-plugin/marketplace.json            ← Claude Code marketplace catalog (one-entry)
├── plugins/copilot-plugin-codex/              ← Shared plugin payload
│   ├── .codex-plugin/plugin.json              ← Codex reads this
│   ├── .claude-plugin/plugin.json             ← Claude Code reads this
│   ├── skills/*/SKILL.md                      ← Codex skills
│   ├── commands/copilot-*.md                  ← Claude Code slash command definitions
│   ├── hooks/hooks.json                       ← Codex hooks (review gate, disabled by default)
│   └── scripts/
│       ├── copilot-exec.sh                    ← The `copilot -p` wrapper
│       └── setup.sh                           ← Install/verify Copilot CLI
└── scripts/validate.sh                        ← Repo validation
```

`plugins/copilot-plugin-codex/scripts/copilot-exec.sh` reads `HOST=codex` or `HOST=claude` from the environment to pick the right state directory (`~/.codex/plugins/...` vs `~/.claude/plugins/...`). Both hosts shell out to the same script.

## Known limitations

1. **MCP behavior in `copilot -p` mode is CLI-version-dependent.** Copilot CLI 1.0.48 loaded the builtin GitHub MCP server during a `rescue` smoke test, but custom/additional MCP server behavior is not covered by this wrapper yet. For MCP-heavy tasks, prefer an interactive Copilot session until the specific server path is verified.
2. **Some Copilot features require a Git repository** (notably diff review and remote access). `$copilot-plugin-codex setup` checks for this.
3. **Each invocation = one Copilot premium request.** Background loops with the review hook enabled can drain quota fast — the hook is disabled by default.

## Status

Late alpha. Manifests, Codex skills, Claude Code slash commands, and scripts are wired up, and `bash scripts/validate.sh` passes. Codex setup/auth and a wrapper-mediated `rescue` smoke test have passed against GitHub Copilot CLI 1.0.48. Claude Code runtime installation and the real review flow still need downstream smoke tests. See [`CLAUDE.md`](./CLAUDE.md) for known gaps and the recommended next-task list.

## License

MIT for original contributions. See [`LICENSE`](./LICENSE). Portions derived from `sendbird/cc-plugin-codex` (Apache 2.0) and, transitively, `openai/codex-plugin-cc` (Apache 2.0) — see [`NOTICE`](./NOTICE).
