#!/usr/bin/env bash
# Canonical daily runner — cron calls THIS, never `claude` directly.
# It captures the full transcript, extracts run cost, heartbeats on failure, and commits —
# so every run leaves a trace even when the agent inside it fails to.
#
# Cron:  0 9 * * *  /path/to/money-bot/scripts/run-daily.sh
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1

RUN_ID="$(date +%Y%m%d-%H%M%S)"
TODAY="$(date +%F)"
mkdir -p logs/transcripts
[ -f .env ] && set -a && . ./.env && set +a

TRANSCRIPT="logs/transcripts/${RUN_ID}.jsonl"
claude -p "$(cat prompts/daily-loop.md)" --output-format stream-json --verbose > "$TRANSCRIPT" 2>> logs/daily.err
EXIT=$?

# Run telemetry from the transcript's result envelope (best-effort)
COST=""; TURNS=""; DUR=""
if command -v jq >/dev/null 2>&1 && [ -s "$TRANSCRIPT" ]; then
  RESULT_LINE="$(jq -c 'select(.type=="result")' "$TRANSCRIPT" 2>/dev/null | tail -1)"
  if [ -n "$RESULT_LINE" ]; then
    COST="$(printf '%s' "$RESULT_LINE" | jq -r '.total_cost_usd // empty' 2>/dev/null)"
    TURNS="$(printf '%s' "$RESULT_LINE" | jq -r '.num_turns // empty' 2>/dev/null)"
    DUR="$(printf '%s' "$RESULT_LINE" | jq -r '.duration_ms // empty' 2>/dev/null)"
  fi
fi

STATUS=ok; [ "$EXIT" -ne 0 ] && STATUS=failed
[ -f runs.csv ] || echo "run_id,date,status,exit_code,duration_ms,num_turns,api_cost_usd,transcript" > runs.csv
echo "${RUN_ID},${TODAY},${STATUS},${EXIT},${DUR},${TURNS},${COST},${TRANSCRIPT}" >> runs.csv

# Crash heartbeat — independent of the agent, so silence never masquerades as passivity
if [ "$STATUS" = "failed" ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  CHAT="${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
  [ -n "$CHAT" ] && curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT}" \
    -d text="🤖⚠️ Daily run ${RUN_ID} FAILED (exit ${EXIT}) — see logs/daily.err. Today's silence is a crash, not passivity." \
    >/dev/null 2>&1 || true
fi

# Commit ritual — the run leaves a git trace even if the agent forgot its trail
git add -A >/dev/null 2>&1
git commit -m "run ${RUN_ID}: ${STATUS}" >/dev/null 2>&1 || true
git push origin HEAD >/dev/null 2>&1 || true
exit 0
