# copilot-plugin-codex — Working Notes

A Codex/Claude Code plugin that delegates work to GitHub Copilot CLI. Fills the gap left by the existing cross-agent plugins (`openai/codex-plugin-cc`, `sendbird/cc-plugin-codex`) — those wrap Codex↔Claude Code; this one wraps Copilot as the worker for either host.

Public-facing intro lives in [`README.md`](./README.md). This file is for active development — what's done, what's untested, what's next.

## Status

**Alpha scaffold.** Structure, manifests, scripts, skill, and slash commands are all in place and `scripts/validate.sh` passes. None of it has been smoke-tested against a real Copilot CLI install yet.

## Conventions worth knowing before editing

- **Dual-targeted from one codebase.** Both `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` ship at the repo root; both `.agents/plugins/marketplace.json` (Codex) and `.claude-plugin/marketplace.json` (Claude Code) catalog this repo as a one-plugin marketplace.
- **`skills/copilot/SKILL.md` is the canonical instruction set** for both hosts. Slash command files under `commands/` are Claude Code-specific — Codex commands currently surface through skill triggering only.
- **`scripts/copilot-exec.sh` is the single invocation wrapper.** Reads `HOST=codex` or `HOST=claude` from env to pick the right state directory.
- **The hooks file ships empty.** `hooks/hooks.json` has the structure but no active hooks. Enabling the review gate is opt-in.

## What works

- `bash scripts/validate.sh` passes (manifest JSON, required files, catalog↔directory cross-check)
- `bash -n` clean on all scripts
- Directory layout matches both Codex and Claude Code plugin conventions per their respective docs

## What's untested (in roughly the order it would matter)

1. **End-to-end install.** Neither `codex plugin marketplace add CrewWorkAI/copilot-plugin-codex` nor `/plugin marketplace add CrewWorkAI/copilot-plugin-codex` has actually been run.
2. **Codex's `$plugin:command` surface.** I documented the commands inside the skill body and didn't create separate `skills/<command>/SKILL.md` subdirs per command. Codex's exact mapping from plugin commands to skill structure isn't crisply documented; if `$copilot:review` doesn't trigger after install, the fix is probably to split `skills/copilot/SKILL.md` into one skill per command.
3. **`${CLAUDE_PLUGIN_ROOT}` resolution in command markdown.** The four `commands/copilot-*.md` files reference `${CLAUDE_PLUGIN_ROOT}/scripts/...`. Need to verify this resolves correctly at runtime in a real Claude Code install.
4. **Copilot CLI flag syntax.** `copilot-exec.sh` assumes `-p`, `-s`, `--allow-tool='shell(git:*)'`, `--allow-all-tools`, `--model`, `--output-format=json`, `--resume`, `--no-resume`, `--continue` all work as expected. Worth cross-checking against `copilot --help` from a current install — at least one of these may have shifted recently.
5. **Background job tracking is racy.** The inline `sed` patches against the metadata JSON in `copilot-exec.sh` aren't atomic and assume `bash`-flavored sed. Should be replaced with `jq` (if available) or a temp-file-then-mv pattern.
6. **Missing commands.** Files for `$copilot:result` and `$copilot:cancel` exist as references in the skill but not as standalone command markdown — `commands/` only has `setup`, `review`, `rescue`, `status`. Need to be added before either is actually usable from Claude Code.

## Known limitations that will not change

- Copilot CLI `-p` mode doesn't support MCP servers ([github/copilot-cli#633](https://github.com/github/copilot-cli/issues/633)). Plugin documents this and points users at interactive Copilot sessions for MCP-dependent work.
- Some Copilot features require being inside a git repo. `$copilot:setup` warns about this.
- Each invocation = one Copilot premium request.

## Suggested next tasks (priority order)

1. **Smoke test the install path.** Install Copilot CLI (`npm install -g @github/copilot`), authenticate (`copilot` once interactively), then install this plugin in Claude Code from the local path. Run `/copilot:setup` and `/copilot:review` on a small dirty branch. Capture what breaks.
2. **Verify Copilot CLI flag syntax.** Run `copilot --help` and confirm every flag `scripts/copilot-exec.sh` uses still exists and means what we expect. Fix any drift.
3. **Resolve the Codex command surface question.** If `$copilot:review` doesn't trigger after install, split the single skill into per-command skills under `skills/`.
4. **Add the missing command files.** `commands/copilot-result.md` and `commands/copilot-cancel.md` to match what the skill documents.
5. **Harden `copilot-exec.sh`.** Replace `sed` metadata patches with `jq` (after checking availability) or atomic temp-rename. Add `shellcheck` to CI.
6. **Real tests.** `bats` or `shunit2` for the wrapper's argument parsing. Currently the CI workflow only runs the layout validator.

## Future work (not for this iteration)

There's a broader orchestration-marketplace idea — a separate repo (working name: `orchestra`) that bundles this plugin alongside others (model-router, cross-provider adversarial review). Lives in chat history, not in this repo. Don't pull it in here; the single-plugin shape is intentional. Revisit after this lands.

## Style notes

- The user (Scott, CrewWorkAI) is a lead software engineer with 15+ years. Skip basic explanations of git, npm, plugin architectures, JSON manifests, etc.
- Prefer direct prose over heavy formatting. Caveats brief, recommendations specific.
- The conversation that produced this scaffold lived in claude.ai chat; the full back-and-forth isn't in this session's context. Work from this file plus the repo. Relevant prior art for surface and naming: `openai/codex-plugin-cc` (Claude Code host, Codex worker) and `sendbird/cc-plugin-codex` (Codex host, Claude Code worker) — this plugin's UX mirrors them deliberately.

## Commands

`scripts/validate.sh` — sanity check the layout. Run it after structural changes.

```bash
bash scripts/validate.sh
```

That's it for now. CI is just this same validator on push/PR.
