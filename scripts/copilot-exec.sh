#!/usr/bin/env bash
# copilot-exec.sh — wrapper around `copilot -p` for delegated invocations from
# Codex or Claude Code. Handles job tracking, JSONL transcript capture, and
# normalized exit codes.
#
# Usage:
#   copilot-exec.sh <command-type> <prompt> [flags...]
#
# Command types:
#   setup                                 Verify Copilot CLI install/auth
#   review                                Run /review on current branch vs --base
#   adversarial-review                    Hostile reviewer framing
#   rescue                                Generic task delegation
#   status [job-id]                       List jobs (or show one)
#   result <job-id>                       Print final transcript of a job
#   cancel <job-id>                       SIGTERM a tracked background job
#
# Common flags:
#   --model <model-id>                    Override Copilot model
#   --background                          Run async; print job id
#   --job-id <id>                         Use a caller-supplied id
#   --base <ref>                          Base ref for review (default: main)
#   --resume <session-id>                 Resume a specific Copilot session
#   --continue                            Resume the most recent Copilot session
#   --all                                 status: include sibling sessions
#   --wait                                status: poll until terminal state
#
# Environment:
#   ORCHESTRA_HOME   ~/.codex/plugins/copilot-plugin-codex (HOST=codex, default)
#                    ~/.claude/plugins/copilot-plugin-codex (HOST=claude)
#   HOST             "codex" (default) or "claude"

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

# -- helpers ----------------------------------------------------------------

have_jq() { command -v jq >/dev/null 2>&1; }

# Atomically patch a JSON metadata file. Falls back to python3 if jq is absent.
meta_set() {
  local file="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp "${file}.XXXXXX")"
  if have_jq; then
    jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$file" > "$tmp"
  else
    python3 - "$file" "$key" "$value" > "$tmp" <<'PY'
import json, sys
path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
data[key] = value
json.dump(data, sys.stdout, indent=2)
PY
  fi
  mv "$tmp" "$file"
}

meta_set_int() {
  local file="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp "${file}.XXXXXX")"
  if have_jq; then
    jq --arg k "$key" --argjson v "$value" '.[$k] = $v' "$file" > "$tmp"
  else
    python3 - "$file" "$key" "$value" > "$tmp" <<'PY'
import json, sys
path, key, value = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(path) as f:
    data = json.load(f)
data[key] = value
json.dump(data, sys.stdout, indent=2)
PY
  fi
  mv "$tmp" "$file"
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# -- arg parsing ------------------------------------------------------------

CMD_TYPE="${1:-}"
shift || true

# For status/result/cancel the next positional is a job id, not a prompt.
case "$CMD_TYPE" in
  status|result|cancel)
    JOB_ARG="${1:-}"
    # only consume it as the job id if it doesn't look like a flag
    case "$JOB_ARG" in
      -*) JOB_ARG="" ;;
      "") ;;
      *)  shift ;;
    esac
    ;;
  *)
    PROMPT="${1:-}"
    shift || true
    ;;
esac

MODEL=""
BACKGROUND=false
JOB_ID=""
BASE_REF="main"
RESUME=""
CONTINUE=false
ALL=false
WAIT=false

while [ $# -gt 0 ]; do
  case "$1" in
    --model)      MODEL="$2"; shift 2 ;;
    --background) BACKGROUND=true; shift ;;
    --job-id)     JOB_ID="$2"; shift 2 ;;
    --base)       BASE_REF="$2"; shift 2 ;;
    --resume)     RESUME="$2"; shift 2 ;;
    --continue)   CONTINUE=true; shift ;;
    --all)        ALL=true; shift ;;
    --wait)       WAIT=true; shift ;;
    --)           shift; break ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# -- setup ------------------------------------------------------------------

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

# -- status -----------------------------------------------------------------

if [ "$CMD_TYPE" = "status" ]; then
  shopt -s nullglob
  metas=("$JOBS_DIR"/*.meta.json)
  shopt -u nullglob
  if [ ${#metas[@]} -eq 0 ]; then
    echo "No tracked jobs in $JOBS_DIR"
    exit 0
  fi

  filter_cwd="$(pwd)"
  if [ -n "$JOB_ARG" ]; then
    f="$JOBS_DIR/$JOB_ARG.meta.json"
    [ -f "$f" ] || { echo "No such job: $JOB_ARG" >&2; exit 1; }
    if $WAIT; then
      deadline=$(( $(date +%s) + 600 ))
      while :; do
        st=$(jq -r .status "$f" 2>/dev/null || echo "")
        case "$st" in
          running) ;;
          *) cat "$f"; exit 0 ;;
        esac
        [ "$(date +%s)" -ge "$deadline" ] && { echo "Wait timeout (10m); job still running." >&2; exit 124; }
        sleep 2
      done
    fi
    cat "$f"
    exit 0
  fi

  printf "%-28s %-22s %-10s %-22s %s\n" "JOB" "TYPE" "STATUS" "STARTED" "MODEL"
  for f in "${metas[@]}"; do
    cwd=$(jq -r .cwd "$f")
    if ! $ALL && [ "$cwd" != "$filter_cwd" ]; then continue; fi
    id=$(jq -r .job_id "$f")
    ty=$(jq -r .type "$f")
    st=$(jq -r .status "$f")
    sa=$(jq -r .started_at "$f")
    md=$(jq -r .model "$f")
    printf "%-28s %-22s %-10s %-22s %s\n" "$id" "$ty" "$st" "$sa" "$md"
  done
  exit 0
fi

# -- result -----------------------------------------------------------------

if [ "$CMD_TYPE" = "result" ]; then
  [ -n "$JOB_ARG" ] || { echo "Usage: result <job-id>" >&2; exit 2; }
  t="$JOBS_DIR/$JOB_ARG.jsonl"
  [ -f "$t" ] || { echo "No transcript for $JOB_ARG (looked at $t)" >&2; exit 1; }
  cat "$t"
  exit 0
fi

# -- cancel -----------------------------------------------------------------

if [ "$CMD_TYPE" = "cancel" ]; then
  [ -n "$JOB_ARG" ] || { echo "Usage: cancel <job-id>" >&2; exit 2; }
  m="$JOBS_DIR/$JOB_ARG.meta.json"
  [ -f "$m" ] || { echo "No such job: $JOB_ARG" >&2; exit 1; }
  pid=$(jq -r '.pid // empty' "$m")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" && echo "Sent SIGTERM to $pid"
  else
    echo "Process already gone."
  fi
  meta_set "$m" status cancelled
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
    if [ -z "${PROMPT:-}" ]; then
      echo "ERROR: rescue requires a prompt." >&2
      exit 2
    fi
    COPILOT_ARGS+=("$PROMPT")
    COPILOT_ARGS+=(--allow-all-tools --output-format=json -s)
    ;;
  *)
    echo "Unknown command type: $CMD_TYPE" >&2
    echo "Valid: setup | review | adversarial-review | rescue | status | result | cancel" >&2
    exit 2
    ;;
esac

[ -n "$MODEL" ]  && COPILOT_ARGS+=(--model "$MODEL")
[ -n "$RESUME" ] && COPILOT_ARGS+=(--resume "$RESUME")
$CONTINUE        && COPILOT_ARGS+=(--continue)

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
  "started_at": "$(now_utc)",
  "cwd": "$(pwd)",
  "model": "${MODEL:-default}",
  "host": "$HOST",
  "status": "running",
  "pid": null
}
EOF

# Allow tests to stub the copilot binary
COPILOT_BIN="${COPILOT_BIN:-copilot}"

if $BACKGROUND; then
  ( "$COPILOT_BIN" "${COPILOT_ARGS[@]}" > "$TRANSCRIPT" 2>&1
    EXIT=$?
    STATUS=$([ $EXIT -eq 0 ] && echo "completed" || echo "failed")
    meta_set "$META" status "$STATUS"
    meta_set_int "$META" exit_code "$EXIT"
  ) &
  CHILD_PID=$!
  meta_set_int "$META" pid "$CHILD_PID"
  echo "Started background job: $JOB_ID (PID $CHILD_PID)"
  echo "Watch: status $JOB_ID  |  Output: result $JOB_ID"
  exit 0
else
  "$COPILOT_BIN" "${COPILOT_ARGS[@]}" | tee "$TRANSCRIPT"
  EXIT=${PIPESTATUS[0]}
  STATUS=$([ "$EXIT" -eq 0 ] && echo "completed" || echo "failed")
  meta_set "$META" status "$STATUS"
  meta_set_int "$META" exit_code "$EXIT"
  exit "$EXIT"
fi
