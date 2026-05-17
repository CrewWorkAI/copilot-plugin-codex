---
description: Verify GitHub Copilot CLI is installed and authenticated.
---

Run the non-interactive setup check for copilot-plugin-codex:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/copilot-exec.sh setup
```

If Copilot CLI is missing, show the install command (`npm install -g @github/copilot`). The user still needs to run `copilot` once interactively to authenticate via `gh auth login` — explain this clearly.

If they're not in a git repo, warn them that some Copilot features (`/review`, remote access) require one.
