---
name: setup
description: Use when the user asks to verify Copilot CLI setup, reports `copilot` not found, hits auth errors, or needs first-time plugin setup.
---

# `$copilot-plugin-codex setup` / `/copilot:setup` — verify GitHub Copilot CLI install + auth

Runs the install/version/auth check for Copilot CLI. Idempotent.

## Invocation

```bash
HOST=<host> bash "<plugin-root>/scripts/copilot-exec.sh" setup
```

Set `<host>` to `codex` or `claude`. Replace `<plugin-root>` with the installed plugin root; in a local checkout, that is the repo root. Claude Code slash commands use `${CLAUDE_PLUGIN_ROOT}` from their command files.

## What it does

1. Confirms `copilot` is on `PATH`. If missing, prints `npm install -g @github/copilot` and exits non-zero.
2. Prints `copilot --version`.
3. Warns if the current directory is not a git repo — Copilot diff review and remote access require one.
4. Prints the configured `ORCHESTRA_HOME` and host.

## Authentication

The CLI binary working ≠ authenticated. To verify auth, run once:

```bash
copilot -p 'Reply with the word OK and nothing else.' -s --allow-all-tools
```

If auth is missing, run `copilot login` and complete the device flow. Headless environments can instead set `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, or `GITHUB_TOKEN`; `gh auth login` is also accepted by Copilot CLI when suitable credentials are available.

## When it fails

- `copilot not found` → install via npm
- `Not authenticated` from a delegated call → run `copilot` interactively once
- Sandbox/trust errors → tell the user to start an interactive `copilot` session in this directory once to establish trust
