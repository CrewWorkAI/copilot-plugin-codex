---
description: Verify GitHub Copilot CLI is installed and authenticated. Installs it via npm if missing.
---

Run the setup script for copilot-plugin-codex:

```bash
HOST=claude bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh
```

If Copilot CLI is missing and npm is available, offer to install it. After install, the user needs to run `copilot` once interactively to authenticate via `gh auth login` — explain this clearly.

If they're not in a git repo, warn them that some Copilot features (`/review`, remote access) require one.
