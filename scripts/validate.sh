#!/usr/bin/env bash
# validate.sh — sanity-check the plugin layout before publishing or pushing.
#
# Verifies:
#   - Required manifests at expected paths
#   - All JSON parses
#   - At least one SKILL.md under the plugin skills/, one per documented command
#   - Bash scripts parse
#   - Shellcheck clean (if installed)
#   - Bats tests pass (if installed)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
PLUGIN_DIR="plugins/copilot-plugin-codex"

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
  "$PLUGIN_DIR/.codex-plugin/plugin.json" \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  "$PLUGIN_DIR/scripts/copilot-exec.sh" \
  "$PLUGIN_DIR/scripts/setup.sh" \
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
  "$PLUGIN_DIR/.codex-plugin/plugin.json" \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  "$PLUGIN_DIR/hooks/hooks.json"
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
if [ -f "$PLUGIN_DIR/.codex-plugin/plugin.json" ]; then
  if python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path("plugins/copilot-plugin-codex/.codex-plugin/plugin.json").read_text())
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
    pass "$PLUGIN_DIR/.codex-plugin/plugin.json has required Codex interface metadata"
  else
    fail "$PLUGIN_DIR/.codex-plugin/plugin.json missing required Codex interface metadata"
  fi
fi

echo
echo "==> Codex marketplace layout"
if python3 - <<'PY'
import json
from pathlib import Path

marketplace = json.loads(Path(".agents/plugins/marketplace.json").read_text())
plugins = marketplace.get("plugins")
if not isinstance(plugins, list) or not plugins:
    raise SystemExit("marketplace has no plugins")

for entry in plugins:
    name = entry.get("name", "<unnamed>")
    source = entry.get("source")
    if not isinstance(source, dict):
        raise SystemExit(f"{name}: missing source object")
    if source.get("source") != "local":
        raise SystemExit(f"{name}: source must be local")

    raw_path = source.get("path")
    if not isinstance(raw_path, str) or not raw_path.startswith("./"):
        raise SystemExit(f"{name}: source.path must be a relative ./ path")

    plugin_path = Path(raw_path).as_posix().removeprefix("./").rstrip("/")
    if not plugin_path or plugin_path == ".":
        raise SystemExit(f"{name}: source.path must not point at the marketplace root")

    manifest = Path(plugin_path) / ".codex-plugin" / "plugin.json"
    if not manifest.is_file():
        raise SystemExit(f"{name}: missing {manifest}")
PY
then
  pass ".agents/plugins/marketplace.json points at concrete Codex plugin directories"
else
  fail ".agents/plugins/marketplace.json has invalid Codex plugin source paths"
fi

echo
echo "==> One SKILL.md per command"
for skill in setup review adversarial-review rescue status result cancel; do
  if [ -f "$PLUGIN_DIR/skills/$skill/SKILL.md" ]; then
    pass "$PLUGIN_DIR/skills/$skill/SKILL.md"
  else
    fail "$PLUGIN_DIR/skills/$skill/SKILL.md missing"
  fi
done

echo
echo "==> One command file per command (Claude Code)"
for cmd in setup review adversarial-review rescue status result cancel; do
  if [ -f "$PLUGIN_DIR/commands/copilot-$cmd.md" ]; then
    pass "$PLUGIN_DIR/commands/copilot-$cmd.md"
  else
    fail "$PLUGIN_DIR/commands/copilot-$cmd.md missing"
  fi
done

echo
echo "==> Codex install/use docs"
if grep -R "codex plugin install" README.md CLAUDE.md >/dev/null 2>&1; then
  fail "Codex docs still reference removed 'codex plugin install' command"
else
  pass "Codex docs avoid removed 'codex plugin install' command"
fi

# Search for a literal $PLUGIN_ROOT reference in docs.
# shellcheck disable=SC2016
if find "$PLUGIN_DIR/skills" -name 'SKILL.md' -print0 | xargs -0 grep -E '\$\{PLUGIN_ROOT\}|\$PLUGIN_ROOT' >/dev/null 2>&1; then
  fail "skills still rely on undefined PLUGIN_ROOT shell variable"
else
  pass "skills avoid undefined PLUGIN_ROOT shell variable"
fi

if find "$PLUGIN_DIR/skills" -name 'SKILL.md' -print0 | xargs -0 grep -E 'HOST=(codex|claude) bash "<plugin-root>' >/dev/null 2>&1; then
  fail "shared skills hard-code one host in plugin-root command snippets"
else
  pass "shared skills keep plugin-root command snippets host-neutral"
fi

echo
echo "==> Bash scripts parse"
script_files=()
while IFS= read -r -d '' f; do
  script_files+=("$f")
done < <(find scripts "$PLUGIN_DIR/scripts" -maxdepth 1 -type f -name '*.sh' -print0)

for f in "${script_files[@]}"; do
  if bash -n "$f" 2>/dev/null; then
    pass "$f"
  else
    fail "$f has syntax errors"
  fi
done

echo
echo "==> Shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "${script_files[@]}"; then
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
