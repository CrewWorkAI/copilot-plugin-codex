#!/usr/bin/env bash
# validate.sh — sanity-check the plugin layout before publishing or pushing.
#
# Verifies:
#   - Required manifests at expected paths
#   - All JSON parses
#   - At least one SKILL.md under skills/, one per documented command
#   - Bash scripts parse
#   - Shellcheck clean (if installed)
#   - Bats tests pass (if installed)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
fail() { echo "  ✗ $1" >&2; fail=1; }
pass() { echo "  ✓ $1"; }
note() { echo "  · $1"; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to validate JSON files. Install Python 3 and re-run scripts/validate.sh." >&2
  exit 1
fi

echo "==> Required files"
for f in \
  .codex-plugin/plugin.json \
  .claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  README.md \
  LICENSE \
  NOTICE
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
echo "==> One SKILL.md per command"
for skill in setup review adversarial-review rescue status result cancel; do
  if [ -f "skills/$skill/SKILL.md" ]; then
    pass "skills/$skill/SKILL.md"
  else
    fail "skills/$skill/SKILL.md missing"
  fi
done

echo
echo "==> One command file per command (Claude Code)"
for cmd in setup review adversarial-review rescue status result cancel; do
  if [ -f "commands/copilot-$cmd.md" ]; then
    pass "commands/copilot-$cmd.md"
  else
    fail "commands/copilot-$cmd.md missing"
  fi
done

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
echo "==> Shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck scripts/*.sh; then
    pass "all scripts clean"
  else
    fail "shellcheck reported issues"
  fi
else
  note "shellcheck not installed — skipping"
fi

echo
echo "==> Bats tests"
if command -v bats >/dev/null 2>&1; then
  if [ -d tests ] && find tests -name '*.bats' | grep -q .; then
    if bats tests/; then
      pass "tests pass"
    else
      fail "bats tests failed"
    fi
  else
    note "no tests/*.bats found"
  fi
else
  note "bats not installed — skipping"
fi

echo
if [ $fail -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "Validation failed." >&2
  exit 1
fi
