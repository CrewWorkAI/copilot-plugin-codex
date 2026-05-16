#!/usr/bin/env bash
# copilot-exec.sh — wrapper around `copilot -p` for delegated invocations from
# Codex or Claude Code. Handles job tracking, JSONL transcript capture, and
# normalized exit codes.
#
# Usage:
#   copilot-exec.sh <command-type> <prompt> [--model <model>] [--background]
#                   [--job-id <id>] [--base <ref>] [--resume <session>] [--fresh]
#
# Command types: review | adversarial-review | rescue | setup
#
# Environment:
#   ORCHESTRA_HOME       — defaults to ~/.codex/plugins/copilot-plugin-codex
#                          (or ~/.claude/plugins/copilot-plugin-codex if HOST=claude)
#   HOST                 — "codex" (default) or "claude"

set -euo pipefail

HOST="${HOST:-codex}"
case "$HOST" in
  codex)  DEFAULT_HOME="$HOME/.codex/plugins/copilot-plugin-codex" ;;
  claude) DEFAULT_HOME="$HOME/.claude/plugins/copilot-plugin-codex" ;;
  *) echo "Unknown HOST: $HOST" >&2; exit 2 ;;
esac
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$DEFAULT_HOME}"
JOBS_DIR="$ORCHESTRA_HOME/jobs"
mkdir -p "$JOBS_DIR"

CMD_TYPE="${1:-}"
shift || true
PROMPT="${1:-}"
shift || true

MODEL=""
BACKGROUND=false
JOB_ID=""
BASE_REF="main"
RESUME=""
FRESH=false

while [ $# -gt 0 ]; do
  case "$1" in
    --model)      MODEL="$2"; shift 2 ;;
    --background) BACKGROUND=true; shift ;;
    --job-id)     JOB_ID="$2"; shift 2 ;;
    --base)       BASE_REF="$2"; shift 2 ;;
    --resume)     RESUME="$2"; shift 2 ;;
    --fresh)      FRESH=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# -- setup check ------------------------------------------------------------

if [ "$CMD_TYPE" = "setup" ]; then
  if ! command -v copilot >/dev/null 2>&1; then
    cat <<EOF >&2
ERROR: GitHub Copilot CLI is not installed.

Install with:
  npm install -g @github/copilot

Then authenticate by running \`copilot\` once interactively in a trusted directory.
EOF
    exit 1
  fi
  VERSION=$(copilot --version 2>/dev/null || echo "unknown")
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "WARNING: not in a git repository — some Copilot CLI features (remote access, /review) require one." >&2
  fi
  echo "Copilot CLI: $VERSION"
  echo "Orchestra home: $ORCHESTRA_HOME"
  echo "Host: $HOST"
  exit 0
fi

# -- build copilot command --------------------------------------------------

COPILOT_ARGS=(-p)

case "$CMD_TYPE" in
  review)
    COPILOT_ARGS+=("/review the changes on this branch compared to $BASE_REF. Focus on bugs, security issues, and edge cases. Be concise. Lead with findings.")
    COPILOT_ARGS+=(-s --allow-tool='shell(git:*)')
    ;;
  adversarial-review)
    COPILOT_ARGS+=("You are an adversarial reviewer. Challenge the assumptions in the recent changes on this branch compared to $BASE_REF. Look for: unchecked edge cases, hidden coupling, premature abstractions, security blind spots, and places where the author optimized for the happy path. Be specific. Cite file:line.")
    COPILOT_ARGS+=(-s --allow-tool='shell(git:*)')
    ;;
  rescue)
    if [ -z "$PROMPT" ]; then
      echo "ERROR: rescue requires a prompt." >&2
      exit 2
    fi
    COPILOT_ARGS+=("$PROMPT")
    COPILOT_ARGS+=(--allow-all-tools --output-format=json -s)
    ;;
  *)
    echo "Unknown command type: $CMD_TYPE" >&2
    echo "Valid: review | adversarial-review | rescue | setup" >&2
    exit 2
    ;;
esac

[ -n "$MODEL" ]  && COPILOT_ARGS+=(--model "$MODEL")
[ -n "$RESUME" ] && COPILOT_ARGS+=(--resume "$RESUME")
$FRESH           && COPILOT_ARGS+=(--no-resume)

# -- run --------------------------------------------------------------------

if [ -z "$JOB_ID" ]; then
  JOB_ID="job-$(date +%s)-$$"
fi
TRANSCRIPT="$JOBS_DIR/$JOB_ID.jsonl"
META="$JOBS_DIR/$JOB_ID.meta.json"

cat > "$META" <<EOF
{
  "job_id": "$JOB_ID",
  "type": "$CMD_TYPE",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cwd": "$(pwd)",
  "model": "${MODEL:-default}",
  "host": "$HOST",
  "status": "running",
  "pid": null
}
EOF

if $BACKGROUND; then
  ( copilot "${COPILOT_ARGS[@]}" > "$TRANSCRIPT" 2>&1
    EXIT=$?
    STATUS=$([ $EXIT -eq 0 ] && echo "completed" || echo "failed")
    # Update metadata (cheap inline sed; jq would be cleaner if available)
    tmp=$(mktemp)
    sed "s/\"status\": \"running\"/\"status\": \"$STATUS\"/" "$META" > "$tmp" && mv "$tmp" "$META"
  ) &
  CHILD_PID=$!
  # Patch PID into metadata
  tmp=$(mktemp)
  sed "s/\"pid\": null/\"pid\": $CHILD_PID/" "$META" > "$tmp" && mv "$tmp" "$META"
  echo "Started background job: $JOB_ID (PID $CHILD_PID)"
  echo "Watch with: \$copilot:status $JOB_ID"
  exit 0
else
  copilot "${COPILOT_ARGS[@]}" | tee "$TRANSCRIPT"
  EXIT=${PIPESTATUS[0]}
  STATUS=$([ $EXIT -eq 0 ] && echo "completed" || echo "failed")
  tmp=$(mktemp)
  sed "s/\"status\": \"running\"/\"status\": \"$STATUS\"/" "$META" > "$tmp" && mv "$tmp" "$META"
  exit $EXIT
fi
