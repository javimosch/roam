#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

make version-check
make build

BIN="$ROOT/roam"
TMP_HOME=$(mktemp -d)
OUT="$TMP_HOME/out"
ERR="$TMP_HOME/err"
cleanup() {
  if [[ -f "$TMP_HOME/last" ]]; then
    job=$(cat "$TMP_HOME/last" 2>/dev/null || true)
    if [[ -n "$job" && -f "$TMP_HOME/.roam/$job.db" ]]; then
      "$BIN" stop "$job" >/dev/null 2>/dev/null || true
      for _ in $(seq 1 20); do
        state=$("$BIN" status "$job" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)
        case "$state" in stopped|done|halted|error) break;; esac
        sleep 0.1
      done
    fi
  fi
  if [[ -n "${job:-}" && -f "$TMP_HOME/.roam/$job.pid" ]]; then
    pid=$(cat "$TMP_HOME/.roam/$job.pid" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      kill -TERM "$pid" 2>/dev/null || true
      for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
    fi
  fi
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT
export HOME="$TMP_HOME"
export DO_NOT_TRACK=1

"$BIN" help-json >"$OUT" 2>"$ERR"
test ! -s "$ERR"
jq -e '.schema == "roam.help/v1" and .commands.guide and .commands.send and (.commands.send.flags | index("--tick")) and .aliases.version and .exit_codes["100"] and (.interactive == false)' "$OUT" >/dev/null

"$BIN" guide >"$OUT" 2>"$ERR"
test ! -s "$ERR"
jq -e '.roam and .one_liner and .model and (.loop | length > 0) and .concepts and .commands and (.examples | length > 0) and (.gotchas | length > 0) and .see_also' "$OUT" >/dev/null

"$BIN" guide --human >"$OUT" 2>"$ERR"
test ! -s "$ERR"
grep -q '^# roam guide' "$OUT"

"$BIN" version >"$OUT" 2>"$ERR"
test ! -s "$ERR"
jq -e '.ok == true and .tool == "roam" and .providers' "$OUT" >/dev/null

"$BIN" help >"$OUT" 2>"$ERR"
test ! -s "$ERR"
grep -q '^roam — leave a working agent' "$OUT"

set +e
"$BIN" status >"$OUT" 2>"$ERR"
rc=$?
set -e
test "$rc" -eq 82
test ! -s "$OUT"
jq -e '.ok == false and .error.code == 82 and .error.type == "missing_target" and (.error.suggestions | length > 0)' "$ERR" >/dev/null

set +e
"$BIN" status does-not-exist >"$OUT" 2>"$ERR"
rc=$?
set -e
test "$rc" -eq 92
test ! -s "$OUT"
jq -e '.ok == false and .error.code == 92 and .error.type == "job_not_found"' "$ERR" >/dev/null

"$BIN" send --local --tick --every 1 --goal smoke-local >"$OUT" 2>"$ERR"
test ! -s "$ERR"
job=$(jq -r '.jobid' "$OUT")
test -n "$job" && test "$job" != null
"$BIN" status "$job" >"$OUT" 2>"$ERR"
test ! -s "$ERR"
jq -e '.status and .jobid and (.recent | type == "array")' "$OUT" >/dev/null
"$BIN" stop "$job" >"$OUT" 2>"$ERR"
test ! -s "$ERR"
jq -e '.ok == true and .cmd == "stop"' "$OUT" >/dev/null

for _ in $(seq 1 30); do
  state=$("$BIN" status "$job" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)
  case "$state" in stopped|done|halted|error) break;; esac
  sleep 0.1
done
test "$state" = stopped || test "$state" = done || test "$state" = halted || test "$state" = error

set +e
"$BIN" send --local --tick >"$OUT" 2>"$ERR"
rc=$?
set -e
test "$rc" -eq 82
test ! -s "$OUT"
jq -e '.error.type == "missing_goal" and .error.code == 82' "$ERR" >/dev/null

echo "roam smoke: ok" >&2
