---
description: Ask GitHub Copilot CLI to review the current branch's changes. Returns a focused list of bugs, security issues, and edge cases.
argument-hint: [--base <ref>] [--background] [--model <model>]
---

Run a GitHub Copilot code review on the current work using the copilot-plugin-codex script.

Execute:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh review "" $ARGUMENTS
```

When Copilot returns, summarize the findings for the user. Group by severity (bug / security / style) and cite file:line where Copilot did. If Copilot finds nothing, say so plainly — do not pad.

If the script exits non-zero, surface the stderr directly. Do not retry automatically; ask the user what to do.
