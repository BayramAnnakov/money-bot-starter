#!/usr/bin/env bash
# run-daily.sh — canonical daily runner. Cron calls THIS, never `claude` directly.
# Liveness layer: single-flight lock (with stale-lock reclaim), per-attempt timeout,
# completion-contract check, auto-resume-once, heartbeat + external dead-man's-switch,
# crash alert, auto-commit (only once the charter is frozen). See OBSERVABILITY.md §Liveness.
#
# Cron (inside the operating window):  0 9 * * *  /path/to/money-bot/scripts/run-daily.sh
set -u
# cron runs with a bare PATH — put the tools we need on it before anything else.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
ROOT="$(pwd)"
[ -f .env ] && set -a && . ./.env && set +a

TIMEOUT_SECS="${RUN_TIMEOUT_SECS:-1500}"
case "$TIMEOUT_SECS" in ''|*[!0-9]*) TIMEOUT_SECS=1500 ;; esac   # a bad value must not disable the cap
MAX_RETRIES="${RUN_MAX_RETRIES:-1}"
case "$MAX_RETRIES" in ''|*[!0-9]*) MAX_RETRIES=1 ;; esac
PUSH_ON_RUN="${PUSH_ON_RUN:-1}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
TODAY="$(date +%F)"
mkdir -p logs/transcripts

# --- helpers (defined before the lock so the pre-flight can use them) ---
owner_chat() { echo "${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"; }
tg() { # tg <chat_id> <text>
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || return 0; [ -n "$1" ] || return 0
  curl -s -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$1" --data-urlencode text="$2" >/dev/null 2>&1 || true
}
hc_ping() { [ -n "${HEALTHCHECK_URL:-}" ] || return 0; curl -s -m 8 "${HEALTHCHECK_URL}${1:-}" >/dev/null 2>&1 || true; }
complete_for() { # 0 iff the day's trail exists: a "## Day … <date>" journal HEADER + a metrics row.
  grep -qE "^## Day .*$1" journal.md 2>/dev/null || return 1   # anchored to the header, not stray body dates
  grep -q "^$1," metrics.csv 2>/dev/null || return 1
  return 0
}

# --- pre-flight: fail-fast on the things cron/reboots/outages silently break (auth, tools, git, engine).
#     scripts/preflight.sh HARD-fails (exit 1) only on universal blockers and alerts the owner itself;
#     it soft-warns (exit 0, alert, proceed) on a degraded-but-usable env (e.g. sandbox engine down). ---
if ! bash "$ROOT/scripts/preflight.sh"; then
  echo "$(date -u +%FT%TZ) run-daily: preflight HARD-FAILED — skipping ${RUN_ID} so a broken env doesn't burn a session" >> logs/daily.err
  hc_ping "/fail"; exit 1
fi

# --- single-flight lock, with stale-lock reclaim (trap misses SIGKILL / power loss) ---
LOCK="$ROOT/.run.lock"
STALE_LOCK_MIN=$(( 2 * TIMEOUT_SECS / 60 + 1 ))
if ! mkdir "$LOCK" 2>/dev/null; then
  oldpid="$(cat "$LOCK/pid" 2>/dev/null)"
  if { [ -n "$oldpid" ] && ! kill -0 "$oldpid" 2>/dev/null; } || [ -n "$(find "$LOCK" -mmin +"$STALE_LOCK_MIN" 2>/dev/null)" ]; then
    echo "$(date -u +%FT%TZ) run-daily: reclaiming stale lock (pid=$oldpid)" >> logs/daily.err
    rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || { echo "lock race, exiting" >> logs/daily.err; exit 0; }
  else
    echo "$(date -u +%FT%TZ) run-daily: another run holds the lock; exiting" >> logs/daily.err; exit 0
  fi
fi
echo "$$" > "$LOCK/pid"
trap 'rm -rf "$LOCK" 2>/dev/null' EXIT INT TERM HUP

# --- idempotence: if today's run already completed, do NOT run the money loop again ---
if complete_for "$TODAY"; then
  echo "$(date -u +%FT%TZ) run-daily: already complete for $TODAY; skipping" >> logs/daily.err
  exit 0
fi

run_attempt() { # run_attempt <prompt> <transcript> ; portable timeout, returns claude's exit (124=timeout)
  local prompt="$1" transcript="$2" cpid waited=0
  claude -p "$prompt" --permission-mode acceptEdits --output-format stream-json --verbose >"$transcript" 2>>logs/daily.err &
  cpid=$!
  while kill -0 "$cpid" 2>/dev/null; do
    sleep 5; waited=$((waited+5))
    if [ "$waited" -ge "$TIMEOUT_SECS" ]; then
      kill -TERM "$cpid" 2>/dev/null; sleep 3; kill -KILL "$cpid" 2>/dev/null; return 124
    fi
  done
  wait "$cpid"
}

BASE_PROMPT="$(cat prompts/daily-loop.md)"
RESUME_HINT="You may have stopped mid-run last attempt (turn/context limit or an API error). Re-read state.md and FINISH the incomplete work; you MUST complete the Trail step (journal entry + metrics row + rewritten state.md) before ending."

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

# The TRAIL is the source of truth: journal+metrics present → DONE regardless of subtype.
if complete_for "$TODAY"; then COMPLETE=1; else COMPLETE=0; fi
if   [ "$EXIT" -eq 124 ];                          then STATUS=timeout
elif [ "$COMPLETE" -eq 1 ];                        then STATUS=ok
elif [ "$EXIT" -ne 0 ] || [ "$IS_ERR" = "true" ];  then STATUS=error
else                                                    STATUS=incomplete; fi

[ -f runs.csv ] || echo "run_id,date,status,exit_code,duration_ms,num_turns,api_cost_usd,attempts,subtype,complete,transcript" > runs.csv
echo "${RUN_ID},${TODAY},${STATUS},${EXIT},${DUR},${TURNS},${COST},$((attempt+1)),${SUBTYPE},${COMPLETE},${TRANSCRIPT}" >> runs.csv

if [ "$COMPLETE" -eq 1 ]; then
  date -u +%FT%TZ > .last-alive
  hc_ping ""
else
  hc_ping "/fail"
  tg "$(owner_chat)" "🤖⚠️ Daily run ${RUN_ID} did NOT complete (status=${STATUS}, subtype=${SUBTYPE:-n/a}, attempts=$((attempt+1))). No trail for ${TODAY}. state.md is preserved — the next run resumes. See logs/daily.err."
fi

# --- commit ritual: ONLY once the charter is frozen (shadow/template stays pristine — never
#     auto-push a placeholder template, and never publish an unfrozen working copy). ---
if ! grep -q "PLACEHOLDER" charter.md 2>/dev/null; then
  git add -A >/dev/null 2>&1
  git commit -m "run ${RUN_ID}: ${STATUS} (complete=${COMPLETE})" >/dev/null 2>&1 || true
  if [ "$PUSH_ON_RUN" = "1" ]; then
    git push origin HEAD >>logs/daily.err 2>&1 || echo "$(date -u +%FT%TZ) run-daily: git push failed (see above)" >> logs/daily.err
  fi
fi
exit 0
