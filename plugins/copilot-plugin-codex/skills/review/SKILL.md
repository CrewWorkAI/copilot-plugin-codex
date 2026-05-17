---
name: review
description: Use when the user asks Copilot to review this branch, check the diff, or provide a second opinion. Do not trigger for hostile-framed review requests.
---

# `$copilot-plugin-codex review` / `/copilot:review` — Copilot review on the current branch

Asks Copilot CLI in non-interactive mode to review the current branch vs a base ref (default `main`).

## Invocation

```bash
HOST=<host> bash "<plugin-root>/scripts/copilot-exec.sh" review "" [flags]
```

Set `<host>` to `codex` or `claude`. Replace `<plugin-root>` with the installed plugin root; in a local checkout, that is the repo root.

Flags:

- `--base <ref>` — compare against this ref instead of `main`
- `--model <model>` — override Copilot's current default
- `--background` — fire and forget; print job id
- `--job-id <id>` — caller-supplied id

## Under the hood

```bash
copilot -p 'Review the changes on this branch compared to <base>. Focus on bugs, security issues, and edge cases. Use git commands as needed. Be concise. Lead with findings and cite file:line when possible.' \
  -s --allow-tool='shell(git:*)'
```

`-s` keeps the output to the agent response only. `--allow-tool='shell(git:*)'` lets Copilot run any `git` subcommand without prompting, which it needs to diff the branch.

## Output handling

When Copilot returns, group findings by severity (bug / security / style) and cite `file:line` where it did. If Copilot finds nothing, say so plainly — do not pad.

## When to escalate

If the user wants a sharper, assumption-challenging review, trigger the `adversarial-review` skill instead. If Copilot's findings prompt actual fixes, hand the work to `rescue` rather than implementing in the host.

## Failure modes

- Non-zero exit → surface stderr verbatim. Do not retry.
- "Not authenticated" → trigger `setup`.
- Quota exhausted → state this and stop; don't retry.
