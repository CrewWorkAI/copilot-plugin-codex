---
description: Ask GitHub Copilot CLI to adversarially review the current branch — assumptions challenged, edge cases probed, happy-path optimism flagged.
argument-hint: [--base <ref>] [--background] [--model <model>]
---

Run an adversarial-framed Copilot review on the current work.

Execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh adversarial-review "" $ARGUMENTS
```

The framing tells Copilot to behave as a hostile reviewer — look for unchecked edge cases, hidden coupling, premature abstractions, security blind spots, and places the author optimized for the happy path. Findings should cite `file:line`.

When Copilot returns, present its findings without softening them. Group by severity and call out the most load-bearing concerns first. If Copilot says the change is clean, report that plainly — don't manufacture criticism.

Do not retry on failure. Surface auth, quota, and sandbox errors verbatim.
