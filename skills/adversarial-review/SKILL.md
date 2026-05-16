---
name: adversarial-review
description: Run a hostile-framed code review via GitHub Copilot CLI on the current branch — Copilot is prompted to challenge assumptions and probe edge cases rather than do a standard review pass. Trigger when the user invokes `$copilot:adversarial-review` / `/copilot:adversarial-review`, asks for a "harsh review", "red team this", "challenge my assumptions", "find what I missed", or otherwise wants a sharper critique than `$copilot:review` would give.
---

# `$copilot:adversarial-review` — hostile-reviewer framing

Same surface as `$copilot:review`, but the prompt instructs Copilot to behave as an adversarial reviewer: unchecked edge cases, hidden coupling, premature abstractions, security blind spots, happy-path optimism.

## Invocation

```bash
HOST=$HOST bash "${PLUGIN_ROOT}/scripts/copilot-exec.sh" adversarial-review "" [flags]
```

Same flags as `review`: `--base`, `--model`, `--background`, `--job-id`.

## Under the hood

```bash
copilot -p 'You are an adversarial reviewer. Challenge the assumptions in the recent changes on this branch compared to <base>. Look for: unchecked edge cases, hidden coupling, premature abstractions, security blind spots, and places where the author optimized for the happy path. Be specific. Cite file:line.' \
  -s --allow-tool='shell(git:*)'
```

## Output handling

Present Copilot's findings without softening. If it says the change is clean, report that plainly — do not manufacture criticism to justify the framing. Lead with the most load-bearing concerns.

## When to use vs `review`

- `review` — first-pass coverage of bugs/security/edge cases
- `adversarial-review` — pre-merge gut check, "what are we missing", design-risk audit

Running both is reasonable for high-stakes changes. Pass `--background` to one so they run in parallel.
