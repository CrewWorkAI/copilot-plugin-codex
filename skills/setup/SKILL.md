---
name: setup
description: Verify GitHub Copilot CLI is installed and authenticated. Trigger when the user invokes `$copilot:setup` / `/copilot:setup`, asks "is Copilot CLI installed", reports a "copilot not found" or auth error from any other copilot-plugin-codex command, or asks how to get the plugin working for the first time.
---

# `$copilot:setup` — verify GitHub Copilot CLI install + auth

Runs the install/version/auth check for Copilot CLI. Idempotent.

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" setup
```

Where `$HOST` is `codex` or `claude`. Most hosts substitute `${PLUGIN_ROOT}` or `${CLAUDE_PLUGIN_ROOT}` automatically when the plugin is installed; in raw shell, point it at the checkout root.

## What it does

1. Confirms `copilot` is on `PATH`. If missing, prints `npm install -g @github/copilot` and exits non-zero.
2. Prints `copilot --version`.
3. Warns if the current directory is not a git repo — Copilot's `/review` and remote access require one.
4. Prints the configured `ORCHESTRA_HOME` and host.

## Authentication

The CLI binary working ≠ authenticated. To verify auth, run once:

```bash
copilot -p 'Reply with the word OK and nothing else.' -s --allow-all-tools
```

If auth is missing, run `copilot` once interactively and complete `gh auth login` (Copilot CLI piggybacks on `gh` credentials).

## When it fails

- `copilot not found` → install via npm
- `Not authenticated` from a delegated call → run `copilot` interactively once
- Sandbox/trust errors → tell the user to start an interactive `copilot` session in this directory once to establish trust
