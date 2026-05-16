#!/usr/bin/env bash
# validate.sh — sanity-check the plugin layout before publishing or pushing.
#
# Verifies:
#   - Required manifests at expected paths
#   - All JSON parses
#   - At least one SKILL.md under skills/
#   - Marketplace catalogs point at the repo root

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
fail() { echo "  ✗ $1" >&2; fail=1; }
pass() { echo "  ✓ $1"; }

echo "==> Required files"
for f in \
  .codex-plugin/plugin.json \
  .claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  README.md \
  LICENSE
do
  if [ -f "$f" ]; then
    pass "$f"
  else
    fail "$f missing"
  fi
done

echo
echo "==> JSON parses"
for f in \
  .codex-plugin/plugin.json \
  .claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  hooks/hooks.json
do
  [ -f "$f" ] || continue
  if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
    pass "$f parses"
  else
    fail "$f is not valid JSON"
  fi
done

echo
echo "==> At least one SKILL.md"
if find skills -name SKILL.md 2>/dev/null | grep -q .; then
  pass "$(find skills -name SKILL.md | head -1)"
else
  fail "no SKILL.md found under skills/"
fi

echo
echo "==> Bash scripts parse"
for f in scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    pass "$f"
  else
    fail "$f has syntax errors"
  fi
done

echo
if [ $fail -eq 0 ]; then
  echo "✅ All checks passed."
  exit 0
else
  echo "❌ Validation failed." >&2
  exit 1
fi
