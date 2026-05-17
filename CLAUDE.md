# copilot-plugin-codex — Working Notes

A Codex/Claude Code plugin that delegates work to GitHub Copilot CLI. Fills the gap left by the existing cross-agent plugins (`openai/codex-plugin-cc`, `sendbird/cc-plugin-codex`) — those wrap Codex↔Claude Code; this one wraps Copilot as the worker for either host.

This is a modified fork of [`sendbird/cc-plugin-codex`](https://github.com/sendbird/cc-plugin-codex) — see [`NOTICE`](./NOTICE) for full attribution. Public-facing intro lives in [`README.md`](./README.md). This file is for active development — what's done, what's untested, what's next.

## Status

**Late alpha.** Structure, manifests, scripts, per-command skills, slash commands, and a `bats` test suite are in place. `bash scripts/validate.sh` passes (layout + JSON + shellcheck + bats). End-to-end install against a real Copilot CLI install still hasn't been smoke-tested in a downstream host (Codex or Claude Code), but `scripts/copilot-exec.sh` has been validated against Copilot CLI 1.0.48's actual `--help` output, so flag drift is no longer a guessed risk.

## Conventions worth knowing before editing

- **Dual-targeted from one codebase.** Both `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` ship at the repo root; both `.agents/plugins/marketplace.json` (Codex) and `.claude-plugin/marketplace.json` (Claude Code) catalog this repo as a one-plugin marketplace.
- **One skill per command.** `skills/{setup,review,adversarial-review,rescue,status,result,cancel}/SKILL.md` — matches the structure used by the upstream `sendbird/cc-plugin-codex` and what Codex expects for `$plugin:command` routing. `skills/copilot/SKILL.md` is a router that handles generic "ask Copilot" requests.
- **`scripts/copilot-exec.sh` is the single invocation wrapper.** Reads `HOST=codex` or `HOST=claude` from env to pick the right state directory. Also dispatches the `status`, `result`, and `cancel` subcommands directly (no `copilot` call needed for those).
- **`COPILOT_BIN` env var lets tests stub the binary.** Default is `copilot`. The bats suite at `tests/copilot-exec.bats` uses a stub on PATH that echoes its argv, so we can assert on the wrapper-built command without burning premium requests.
- **The hooks file ships empty.** `hooks/hooks.json` has the structure but no active hooks. Enabling the review gate is opt-in.

## What works

- `bash scripts/validate.sh` passes: layout, JSON parse, per-command SKILL.md present, per-command Claude Code command file present, `bash -n` clean, `shellcheck` clean, `bats tests/` green (20/20).
- All wrapper flags map 1:1 to actual `copilot --help` output from CLI 1.0.48: `-p`, `-s`, `--allow-tool='shell(git:*)'`, `--allow-all-tools`, `--model`, `--output-format=json`, `--resume`, `--continue`.
- Job metadata writes are atomic (`jq` to temp file + `mv`); falls back to `python3` if `jq` is unavailable at runtime.

## What's still untested (in roughly the order it would matter)

1. **End-to-end invocation in a host.** A local-path `codex plugin marketplace add ./` smoke test succeeds, but `$copilot:*` commands have not been exercised inside a fresh Codex thread and Claude Code install has not been smoke-tested yet.
2. **Real Copilot review invocation.** The wrapper now uses a normal non-interactive review prompt instead of Copilot's interactive `/review` slash command, but the full flow still needs a real-CLI smoke test.
3. **`${CLAUDE_PLUGIN_ROOT}` resolution.** The seven `commands/copilot-*.md` files reference `${CLAUDE_PLUGIN_ROOT}/scripts/...`. Needs verification at runtime in a real Claude Code install.
4. **Codex `$plugin:command` mapping.** Splitting the skill into per-command subdirs matches `sendbird/cc-plugin-codex`'s structure, so this should work, but it still needs a fresh-session check for our specific command names.

## Known limitations that will not change

- Copilot CLI `-p` mode doesn't support MCP servers ([github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633)). Plugin documents this in every skill that might need MCP and points users at interactive Copilot sessions.
- Some Copilot features require being inside a git repo. `$copilot:setup` warns about this.
- Each invocation = one Copilot premium request. Cancellation does not refund it.

## Remaining nice-to-haves

1. **Real install smoke test.** Install the plugin from a local path into Claude Code (`/plugin marketplace add ./` from the repo root), run `/copilot:setup`, then `/copilot:review` on a small dirty branch. Capture what breaks.
2. **Same against Codex.** After `codex plugin marketplace add ./`, start a fresh Codex thread and verify `$copilot:review` actually triggers the `review` skill.
3. **Enable the hook.** `hooks/hooks.json` is currently `[]`. Wire a Stop hook that fires `$copilot:review` post-edit, gated behind an opt-in flag.

## Future work (not for this iteration)

There's a broader orchestration-marketplace idea — a separate repo (working name: `orchestra`) that bundles this plugin alongside others (model-router, cross-provider adversarial review). Lives in chat history, not in this repo. Don't pull it in here; the single-plugin shape is intentional. Revisit after this lands.

## Style notes

- The user (Scott, CrewWorkAI) is a lead software engineer with 15+ years. Skip basic explanations of git, npm, plugin architectures, JSON manifests, etc.
- Prefer direct prose over heavy formatting. Caveats brief, recommendations specific.
- Relevant prior art for surface and naming: `openai/codex-plugin-cc` (Claude Code host, Codex worker) and `sendbird/cc-plugin-codex` (Codex host, Claude Code worker). This plugin is a modified fork of the latter, retargeted at Copilot as the worker. See `NOTICE`.

## Commands

`scripts/validate.sh` — sanity check the layout. Run it after structural changes.

```bash
bash scripts/validate.sh
```

Runs JSON parse, layout cross-check, `bash -n`, `shellcheck`, and `bats tests/`. CI runs the same script.
