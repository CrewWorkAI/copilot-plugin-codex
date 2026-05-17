# copilot-plugin-codex — Working Notes

A Codex/Claude Code plugin that delegates work to GitHub Copilot CLI. Fills the gap left by the existing cross-agent plugins (`openai/codex-plugin-cc`, `sendbird/cc-plugin-codex`) — those wrap Codex↔Claude Code; this one wraps Copilot as the worker for either host.

This is a modified fork of [`sendbird/cc-plugin-codex`](https://github.com/sendbird/cc-plugin-codex) — see [`NOTICE`](./NOTICE) for full attribution. Public-facing intro lives in [`README.md`](./README.md). This file is for active development — what's done, what's untested, what's next.

## Status

**Late alpha.** Structure, manifests, scripts, per-command Codex skills, Claude Code slash commands, and a `bats` test suite are in place. `bash scripts/validate.sh` passes; `shellcheck` and `bats` run when installed. GitHub Copilot CLI 1.0.48 has been installed/authenticated with `copilot login`, and the Codex path has been smoke-tested in-session with `$copilot-plugin-codex setup` plus a wrapper-mediated `rescue` job (`codex-smoke-rescue`, exit 0, no files modified). Claude Code runtime installation and the real review flow still need downstream smoke tests.

## Conventions worth knowing before editing

- **Dual-targeted from one codebase.** The root marketplace files (`.agents/plugins/marketplace.json` for Codex and `.claude-plugin/marketplace.json` for Claude Code) both point at the shared plugin payload in `plugins/copilot-plugin-codex/`. Codex rejects a marketplace entry whose plugin source path is `./`, so keep the non-root plugin directory.
- **One skill per command.** `plugins/copilot-plugin-codex/skills/{setup,review,adversarial-review,rescue,status,result,cancel}/SKILL.md` — matches what Codex exposes as `$copilot-plugin-codex <skill>`. `plugins/copilot-plugin-codex/skills/copilot/SKILL.md` is a router that handles generic "ask Copilot" requests.
- **`plugins/copilot-plugin-codex/scripts/copilot-exec.sh` is the single invocation wrapper.** Reads `HOST=codex` or `HOST=claude` from env to pick the right state directory. Also dispatches the `status`, `result`, and `cancel` subcommands directly (no `copilot` call needed for those).
- **`COPILOT_BIN` env var lets tests stub the binary.** Default is `copilot`. The bats suite at `tests/copilot-exec.bats` uses a stub on PATH that echoes its argv, so we can assert on the wrapper-built command without burning premium requests.
- **The hooks file ships empty.** `plugins/copilot-plugin-codex/hooks/hooks.json` has the structure but no active hooks. Enabling the review gate is opt-in.

## What works

- `bash scripts/validate.sh` passes: layout, JSON parse, Codex marketplace path validation, per-command SKILL.md present, per-command Claude Code command file present, and `bash -n` clean. `shellcheck` and `bats tests/` are included in the validator and run when installed.
- All wrapper flags map 1:1 to actual `copilot --help` output from CLI 1.0.48: `-p`, `-s`, `--allow-tool='shell(git:*)'`, `--allow-all-tools`, `--model`, `--output-format=json`, `--resume`, `--continue`.
- Job metadata writes are atomic (`jq` to temp file + `mv`); falls back to `python3` if `jq` is unavailable at runtime.
- Codex setup/auth works with Copilot CLI 1.0.48 via `copilot login`, and a wrapper-mediated `rescue` smoke test completed with zero file changes.

## What's still untested (in roughly the order it would matter)

1. **Claude Code install/runtime.** The seven `plugins/copilot-plugin-codex/commands/copilot-*.md` files reference `${CLAUDE_PLUGIN_ROOT}/scripts/...`. Needs verification at runtime in a real Claude Code install.
2. **Real Copilot review invocation.** The wrapper now uses a normal non-interactive review prompt instead of Copilot's interactive `/review` slash command, but the full review flow still needs a real-CLI smoke test on a branch with changes.
3. **Custom/additional MCP behavior in `copilot -p`.** Copilot CLI 1.0.48 loaded the builtin GitHub MCP server during a `rescue` smoke test, but custom/additional MCP server paths have not been verified through the wrapper.

## Known limitations that will not change

- Copilot CLI `-p` MCP behavior is version/source dependent. The builtin GitHub MCP server loaded in CLI 1.0.48 during a `rescue` smoke test; custom/additional MCP server behavior remains unverified through this wrapper.
- Some Copilot features require being inside a git repo. `$copilot-plugin-codex setup` warns about this.
- Each invocation = one Copilot premium request. Cancellation does not refund it.

## Remaining nice-to-haves

1. **Claude Code smoke test.** Install the plugin from a local path into Claude Code (`/plugin marketplace add ./` from the repo root), run `/copilot:setup`, then `/copilot:review` on a small dirty branch. Capture what breaks.
2. **Real review smoke test in Codex.** Use `$copilot-plugin-codex review` on a small dirty branch and verify findings/transcript behavior.
3. **Enable the hook.** `plugins/copilot-plugin-codex/hooks/hooks.json` is currently `[]`. Wire a Stop hook that fires a review post-edit, gated behind an opt-in flag.

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

Runs JSON parse, layout cross-check, `bash -n`, and, when installed, `shellcheck` and `bats tests/`. CI runs the same script.
