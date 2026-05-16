---
name: review
description: Delegate a code review of the current branch to GitHub Copilot CLI's built-in `/review` agent. Trigger when the user invokes `$copilot:review` / `/copilot:review`, asks "have Copilot review this", "get a second opinion from Copilot", "review my branch with Copilot", or otherwise asks for Copilot's review specifically (as opposed to a review from the host agent itself). Do not trigger when the user wants a sharper, hostile-framed review — use `adversarial-review` instead.
---

# `$copilot:review` — Copilot `/review` on the current branch

Runs Copilot CLI's built-in `/review` slash command in non-interactive mode against the current branch vs a base ref (default `main`).

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" review "" [flags]
```

Flags:

- `--base <ref>` — compare against this ref instead of `main`
- `--model <model>` — override Copilot's default (Claude Sonnet 4.5 as of CLI 1.0.x)
- `--background` — fire and forget; print job id
- `--job-id <id>` — caller-supplied id

## Under the hood

```bash
copilot -p '/review the changes on this branch compared to <base>. Focus on bugs, security issues, and edge cases. Be concise. Lead with findings.' \
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
