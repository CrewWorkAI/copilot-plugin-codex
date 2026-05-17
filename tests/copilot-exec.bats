#!/usr/bin/env bats
# Tests for scripts/copilot-exec.sh — exercise the arg-parsing and command-routing
# paths without actually calling Copilot CLI. A stub `copilot` is dropped on PATH
# that echoes its argv to stdout, so we can assert on the args the wrapper built.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  EXEC="${REPO_ROOT}/scripts/copilot-exec.sh"

  TEST_HOME="$(mktemp -d)"
  STUB_DIR="$(mktemp -d)"

  cat > "$STUB_DIR/copilot" <<'STUB'
#!/usr/bin/env bash
# Print args one per line so tests can grep them deterministically.
printf 'COPILOT_ARGV:\n'
for a in "$@"; do printf '  %s\n' "$a"; done
STUB
  chmod +x "$STUB_DIR/copilot"

  export PATH="$STUB_DIR:$PATH"
  export ORCHESTRA_HOME="$TEST_HOME/orchestra"
  export HOST=claude
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_DIR"
}

# Keep this in sync with the external commands used by scripts/copilot-exec.sh
# in the jq-free rescue/status path.
NOJQ_COMMANDS=(bash cat date mkdir mktemp mv python3 tee)

# ---- routing ---------------------------------------------------------------

@test "rejects unknown command type" {
  run bash "$EXEC" frobnicate "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown command type"* ]]
}

@test "rescue requires a non-empty prompt" {
  run bash "$EXEC" rescue ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"rescue requires a prompt"* ]]
}

@test "rejects unknown flag" {
  run bash "$EXEC" review "" --bogus value
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "rejects missing values for valued flags" {
  for flag in --model --job-id --base --resume; do
    run bash "$EXEC" rescue "task" "$flag"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing value for $flag"* ]]
  done
}

@test "rejects flag-like values for valued flags" {
  run bash "$EXEC" rescue "task" --model --background
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing value for --model"* ]]
}

@test "rejects unknown HOST" {
  HOST=mystery run bash "$EXEC" setup
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown HOST"* ]]
}

# ---- setup -----------------------------------------------------------------

@test "setup succeeds when copilot stub exists" {
  run bash "$EXEC" setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Host: claude"* ]]
}

@test "setup fails when copilot missing" {
  saved="$PATH"
  # Strip everywhere a real or stubbed copilot binary might live, but keep
  # /bin and /usr/bin so bash/date/jq stay reachable.
  filtered="$(printf '%s' "$PATH" | tr ':' '\n' \
    | grep -v -F "$STUB_DIR" \
    | grep -v -E '(node|copilot|nvm|\.bin)' \
    | paste -sd: -)"
  PATH="$filtered"
  run bash "$EXEC" setup
  PATH="$saved"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
}

# ---- argv building ---------------------------------------------------------

@test "review builds non-interactive prompt with default base=main and shell(git:*) allow" {
  run bash "$EXEC" review ""
  [ "$status" -eq 0 ]
  [[ "$output" != *"/review"* ]]
  [[ "$output" == *"compared to main"* ]]
  [[ "$output" == *"--allow-tool=shell(git:*)"* ]]
  [[ "$output" == *"-s"* ]]
}

@test "review honors --base" {
  run bash "$EXEC" review "" --base release/2026.05
  [ "$status" -eq 0 ]
  [[ "$output" == *"compared to release/2026.05"* ]]
}

@test "adversarial-review uses hostile framing" {
  run bash "$EXEC" adversarial-review ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"adversarial reviewer"* ]]
}

@test "rescue passes prompt and tool-permission flags" {
  run bash "$EXEC" rescue "refactor the auth handler"
  [ "$status" -eq 0 ]
  [[ "$output" == *"refactor the auth handler"* ]]
  [[ "$output" == *"--allow-all-tools"* ]]
  [[ "$output" == *"--output-format=json"* ]]
}

@test "--model is forwarded" {
  run bash "$EXEC" rescue "do a thing" --model gpt-5.3-codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"--model"* ]]
  [[ "$output" == *"gpt-5.3-codex"* ]]
}

@test "--continue is forwarded" {
  run bash "$EXEC" rescue "continue something" --continue
  [ "$status" -eq 0 ]
  [[ "$output" == *"--continue"* ]]
}

@test "--resume is forwarded with its value" {
  run bash "$EXEC" rescue "resume something" --resume abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"--resume"* ]]
  [[ "$output" == *"abc123"* ]]
}

# ---- job tracking ----------------------------------------------------------

@test "foreground run writes meta + transcript with completed status" {
  run bash "$EXEC" rescue "hi" --job-id myjob
  [ "$status" -eq 0 ]
  [ -f "$ORCHESTRA_HOME/jobs/myjob.meta.json" ]
  [ -f "$ORCHESTRA_HOME/jobs/myjob.jsonl" ]
  status=$(jq -r .status "$ORCHESTRA_HOME/jobs/myjob.meta.json")
  [ "$status" = "completed" ]
}

@test "foreground failure still records failed metadata and stderr transcript" {
  cat > "$STUB_DIR/copilot" <<'STUB'
#!/usr/bin/env bash
echo "stdout line"
echo "stderr line" >&2
exit 7
STUB
  chmod +x "$STUB_DIR/copilot"

  run bash "$EXEC" rescue "boom" --job-id failjob
  [ "$status" -eq 7 ]
  meta="$ORCHESTRA_HOME/jobs/failjob.meta.json"
  [ "$(jq -r .status "$meta")" = "failed" ]
  [ "$(jq -r .exit_code "$meta")" = "7" ]
  transcript="$ORCHESTRA_HOME/jobs/failjob.jsonl"
  [[ "$(cat "$transcript")" == *"stdout line"* ]]
  [[ "$(cat "$transcript")" == *"stderr line"* ]]
}

@test "metadata stays valid json when cwd contains quotes" {
  weird_dir="$TEST_HOME/dir\"withquote"
  mkdir -p "$weird_dir"
  (
    cd "$weird_dir"
    bash "$EXEC" rescue "quoted cwd" --job-id quotedcwd >/dev/null
  )
  meta="$ORCHESTRA_HOME/jobs/quotedcwd.meta.json"
  [ "$(jq -r .cwd "$meta")" = "$weird_dir" ]
}

@test "background run prints job id and stores PID" {
  run bash "$EXEC" rescue "long task" --background --job-id bgjob
  [ "$status" -eq 0 ]
  [[ "$output" == *"bgjob"* ]]
  # Give the backgrounded subshell a moment to update metadata.
  for _ in 1 2 3 4 5; do
    sleep 0.2
    pid=$(jq -r '.pid // empty' "$ORCHESTRA_HOME/jobs/bgjob.meta.json" 2>/dev/null || echo "")
    [ -n "$pid" ] && break
  done
  [ -n "$pid" ]
}

# ---- status / result / cancel ---------------------------------------------

@test "status with no jobs prints an explicit empty message" {
  run bash "$EXEC" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"No tracked jobs"* ]]
}

@test "status lists jobs from current cwd by default" {
  bash "$EXEC" rescue "first" --job-id j1 >/dev/null
  run bash "$EXEC" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"j1"* ]]
}

@test "status accepts --wait before job id" {
  bash "$EXEC" rescue "first" --job-id waitjob >/dev/null
  run bash "$EXEC" status --wait waitjob
  [ "$status" -eq 0 ]
  [[ "$output" == *"waitjob"* ]]
}

@test "status falls back to python3 when jq is unavailable" {
  nojq_dir="$(mktemp -d)"
  for cmd in "${NOJQ_COMMANDS[@]}"; do
    ln -s "$(command -v "$cmd")" "$nojq_dir/$cmd"
  done
  cp "$STUB_DIR/copilot" "$nojq_dir/copilot"

  PATH="$nojq_dir" bash "$EXEC" rescue "python fallback" --job-id pyjob >/dev/null
  run env PATH="$nojq_dir" bash "$EXEC" status pyjob
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"job_id\": \"pyjob\""* ]]

  rm -rf "$nojq_dir"
}

@test "result fails when transcript missing" {
  run bash "$EXEC" result nonesuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"No transcript"* ]]
}

@test "rejects invalid caller-supplied job ids" {
  run bash "$EXEC" rescue "hi" --job-id ../escape
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid job id"* ]]
}

@test "rejects hidden caller-supplied job ids" {
  run bash "$EXEC" rescue "hi" --job-id .hidden
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid job id"* ]]
}

@test "rejects caller-supplied job ids containing dot-dot" {
  run bash "$EXEC" rescue "hi" --job-id release..candidate
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid job id"* ]]
}

@test "result prints transcript when present" {
  bash "$EXEC" rescue "two" --job-id j2 >/dev/null
  run bash "$EXEC" result j2
  [ "$status" -eq 0 ]
  [[ "$output" == *"COPILOT_ARGV"* ]]
}

@test "cancel marks an unknown PID's job as cancelled" {
  bash "$EXEC" rescue "three" --job-id j3 >/dev/null
  # Manually set a bogus PID so cancel exercises the "already gone" path.
  meta="$ORCHESTRA_HOME/jobs/j3.meta.json"
  jq '.pid = 999999 | .status = "running"' "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"
  run bash "$EXEC" cancel j3
  [ "$status" -eq 0 ]
  status=$(jq -r .status "$meta")
  [ "$status" = "cancelled" ]
}

@test "cancel rejects invalid pid metadata" {
  bash "$EXEC" rescue "three" --job-id j4 >/dev/null
  meta="$ORCHESTRA_HOME/jobs/j4.meta.json"
  jq '.pid = -1 | .status = "running"' "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"
  run bash "$EXEC" cancel j4
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid PID"* ]]
}

@test "cancel rejects implausibly large pid metadata" {
  bash "$EXEC" rescue "three" --job-id j5 >/dev/null
  meta="$ORCHESTRA_HOME/jobs/j5.meta.json"
  jq '.pid = 999999999 | .status = "running"' "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"
  run bash "$EXEC" cancel j5
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid PID"* ]]
}
