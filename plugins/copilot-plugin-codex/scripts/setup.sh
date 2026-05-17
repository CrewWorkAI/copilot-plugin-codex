#!/usr/bin/env bash
# setup.sh — install/verify GitHub Copilot CLI for use with copilot-plugin-codex.
#
# Idempotent: safe to run multiple times.

set -euo pipefail

echo "==> Checking for GitHub Copilot CLI..."

if command -v copilot >/dev/null 2>&1; then
  VERSION=$(copilot --version 2>/dev/null || echo "unknown")
  echo "    Found: $VERSION"
else
  echo "    Not found."
  if command -v npm >/dev/null 2>&1; then
    read -r -p "    Install GitHub Copilot CLI via npm? [y/N] " ans
    case "$ans" in
      y|Y|yes|YES)
        npm install -g @github/copilot
        ;;
      *)
        echo "    Skipped. Install manually: npm install -g @github/copilot" >&2
        exit 1
        ;;
    esac
  else
    echo "    npm not found. Install Node.js 18+ first, then run: npm install -g @github/copilot" >&2
    exit 1
  fi
fi

echo
echo "==> Checking authentication..."
if copilot --version >/dev/null 2>&1; then
  echo "    Copilot CLI binary works. To verify auth, run a quick test:"
  echo "      copilot -p 'Reply with the word OK and nothing else.' -s --allow-all-tools"
  echo
  echo "    If auth is missing, run \`copilot login\`, or set COPILOT_GITHUB_TOKEN, GH_TOKEN, or GITHUB_TOKEN."
fi

echo
echo "==> Setup complete."
echo "    Try: \$copilot-plugin-codex review  (Codex) or  /copilot:review  (Claude Code)"
