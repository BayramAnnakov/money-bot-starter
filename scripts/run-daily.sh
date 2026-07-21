#!/usr/bin/env bash
# run-daily.sh — canonical daily runner. Cron calls THIS, never `claude` directly.
# Liveness layer: single-flight lock, per-attempt timeout, completion-contract check,
# auto-resume-once, heartbeat + external dead-man's-switch, crash alert, auto-commit.
# See OBSERVABILITY.md §Liveness for the design.
#
# Cron (inside the operating window):  0 9 * * *  /path/to/money-bot/scripts/run-daily.sh
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
ROOT="$(pwd)"
[ -f .env ] && set -a && . ./.env && set +a

TIMEOUT_SECS="${RUN_TIMEOUT_SECS:-1500}"   # 25-min hard cap per attempt (a hang can't run forever)
MAX_RETRIES="${RUN_MAX_RETRIES:-1}"        # auto-resume attempts after the first run
PUSH_ON_RUN="${PUSH_ON_RUN:-1}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
TODAY="$(date +%F)"
mkdir -p logs/transcripts

# --- single-flight lock (atomic mkdir; works on macOS bash 3.2, no flock dependency) ---
LOCK="$ROOT/.run.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "$(date -u +%FT%TZ) run-daily: another run holds the lock; exiting" >> logs/daily.err
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# --- helpers ---
owner_chat() { echo "${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"; }
tg() { # tg <chat_id> <text>
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || return 0; [ -n "$1" ] || return 0
  curl -s -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$1" --data-urlencode text="$2" >/dev/null 2>&1 || true
}
hc_ping() { # hc_ping ""  (alive)  |  hc_ping "/fail"  (escalate)
  [ -n "${HEALTHCHECK_URL:-}" ] || return 0
  curl -s -m 8 "${HEALTHCHECK_URL}${1:-}" >/dev/null 2>&1 || true
}
complete_for() { # 0 if the day's append-only trail exists (journal entry + metrics row)
  grep -q "$1" journal.md 2>/dev/null || return 1
  grep -q "^$1," metrics.csv 2>/dev/null || return 1
  return 0
}
run_attempt() { # run_attempt <prompt> <transcript> ; portable timeout, returns claude's exit (124=timeout)
  local prompt="$1" transcript="$2" cpid waited=0
  claude -p "$prompt" --output-format stream-json --verbose >"$transcript" 2>>logs/daily.err &
  cpid=$!
  while kill -0 "$cpid" 2>/dev/null; do
    sleep 5; waited=$((waited+5))
    if [ "$waited" -ge "$TIMEOUT_SECS" ]; then
      kill -TERM "$cpid" 2>/dev/null; sleep 3; kill -KILL "$cpid" 2>/dev/null
      return 124
    fi
  done
  wait "$cpid"
}

BASE_PROMPT="$(cat prompts/daily-loop.md)"
RESUME_HINT="You may have stopped mid-run last attempt (turn/context limit or an API error). Re-read state.md and FINISH the incomplete work; you MUST complete the Trail step (journal entry + metrics row + rewritten state.md) before ending."

# --- run, with one auto-resume if the trail is incomplete ---
attempt=0; EXIT=0; TRANSCRIPT=""
while :; do
  TRANSCRIPT="logs/transcripts/${RUN_ID}-a${attempt}.jsonl"
  if [ "$attempt" -eq 0 ]; then P="$BASE_PROMPT"; else P="${RESUME_HINT}"$'\n\n'"${BASE_PROMPT}"; fi
  run_attempt "$P" "$TRANSCRIPT"; EXIT=$?
  complete_for "$TODAY" && break
  [ "$attempt" -ge "$MAX_RETRIES" ] && break
  attempt=$((attempt+1))
  echo "$(date -u +%FT%TZ) run-daily: incomplete trail (exit=$EXIT); auto-resume attempt $attempt" >> logs/daily.err
  sleep 30
done

# --- telemetry from the last transcript's result envelope (best-effort) ---
COST=""; TURNS=""; DUR=""; SUBTYPE=""; IS_ERR=""
if command -v jq >/dev/null 2>&1 && [ -s "$TRANSCRIPT" ]; then
  RL="$(jq -c 'select(.type=="result")' "$TRANSCRIPT" 2>/dev/null | tail -1)"
  if [ -n "$RL" ]; then
    COST="$(printf '%s' "$RL" | jq -r '.total_cost_usd // empty' 2>/dev/null)"
    TURNS="$(printf '%s' "$RL" | jq -r '.num_turns // empty' 2>/dev/null)"
    DUR="$(printf '%s' "$RL" | jq -r '.duration_ms // empty' 2>/dev/null)"
    SUBTYPE="$(printf '%s' "$RL" | jq -r '.subtype // empty' 2>/dev/null)"
    IS_ERR="$(printf '%s' "$RL" | jq -r '.is_error // empty' 2>/dev/null)"
  fi
fi

# The TRAIL is the source of truth ("a run that leaves no trace didn't happen"): if the day's
# journal+metrics exist, the run is DONE regardless of subtype; else it stopped mid-task.
if complete_for "$TODAY"; then COMPLETE=1; else COMPLETE=0; fi
if   [ "$EXIT" -eq 124 ];                          then STATUS=timeout
elif [ "$COMPLETE" -eq 1 ];                        then STATUS=ok
elif [ "$EXIT" -ne 0 ] || [ "$IS_ERR" = "true" ];  then STATUS=error
else                                                    STATUS=incomplete; fi

# --- runs.csv (extended telemetry; schema frozen in OBSERVABILITY.md) ---
[ -f runs.csv ] || echo "run_id,date,status,exit_code,duration_ms,num_turns,api_cost_usd,attempts,subtype,complete,transcript" > runs.csv
echo "${RUN_ID},${TODAY},${STATUS},${EXIT},${DUR},${TURNS},${COST},$((attempt+1)),${SUBTYPE},${COMPLETE},${TRANSCRIPT}" >> runs.csv

# --- heartbeat + dead-man's-switch + alert ---
if [ "$COMPLETE" -eq 1 ]; then
  date -u +%FT%TZ > .last-alive
  hc_ping ""
else
  hc_ping "/fail"
  tg "$(owner_chat)" "🤖⚠️ Daily run ${RUN_ID} did NOT complete (status=${STATUS}, subtype=${SUBTYPE:-n/a}, attempts=$((attempt+1))). No trail for ${TODAY}. state.md is preserved — the next run resumes. See logs/daily.err."
fi

# --- commit ritual: the run leaves a git trace even if the agent forgot its own ---
git add -A >/dev/null 2>&1
git commit -m "run ${RUN_ID}: ${STATUS} (complete=${COMPLETE})" >/dev/null 2>&1 || true
[ "$PUSH_ON_RUN" = "1" ] && git push origin HEAD >/dev/null 2>&1 || true
exit 0
