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

had_failures=0
fail() { echo "  ✗ $1" >&2; had_failures=1; }
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
echo "==> Codex manifest metadata"
if [ -f ".codex-plugin/plugin.json" ]; then
  if python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path(".codex-plugin/plugin.json").read_text())
required_top = ["author", "interface"]
required_interface = [
    "displayName",
    "shortDescription",
    "longDescription",
    "developerName",
    "category",
    "capabilities",
    "websiteURL",
    "privacyPolicyURL",
    "termsOfServiceURL",
    "defaultPrompt",
]

missing = [key for key in required_top if key not in manifest]
interface = manifest.get("interface")
if isinstance(interface, dict):
    missing.extend(f"interface.{key}" for key in required_interface if key not in interface)
else:
    missing.extend(f"interface.{key}" for key in required_interface)

if missing:
    raise SystemExit("missing: " + ", ".join(missing))
PY
  then
    pass ".codex-plugin/plugin.json has required Codex interface metadata"
  else
    fail ".codex-plugin/plugin.json missing required Codex interface metadata"
  fi
fi

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
echo "==> Codex install/use docs"
if grep -R "codex plugin install" README.md CLAUDE.md >/dev/null 2>&1; then
  fail "Codex docs still reference removed 'codex plugin install' command"
else
  pass "Codex docs avoid removed 'codex plugin install' command"
fi

if find skills -name 'SKILL.md' -print0 | xargs -0 grep -E '\$\{PLUGIN_ROOT\}|\$PLUGIN_ROOT' >/dev/null 2>&1; then
  fail "skills still rely on undefined PLUGIN_ROOT shell variable"
else
  pass "skills avoid undefined PLUGIN_ROOT shell variable"
fi

if find skills -name 'SKILL.md' -print0 | xargs -0 grep -E 'HOST=(codex|claude) bash "<plugin-root>' >/dev/null 2>&1; then
  fail "shared skills hard-code one host in plugin-root command snippets"
else
  pass "shared skills keep plugin-root command snippets host-neutral"
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
if [ $had_failures -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "Validation failed." >&2
  exit 1
fi
