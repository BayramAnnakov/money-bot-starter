#!/usr/bin/env bash
# check-liveness.sh — independent watchdog. NO `claude` dependency, so it survives the exact
# failures the daily loop can't report (crash, turn-limit stop, cron that never fired while the
# machine was on). Cron it a few times inside the operating window. See OBSERVABILITY.md §Liveness.
#
# Cron:  0 12,15,18 * * *  /path/to/money-bot/scripts/check-liveness.sh
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
[ -f .env ] && set -a && . ./.env && set +a

TODAY="$(date +%F)"
STALE_AFTER_HOURS="${STALE_AFTER_HOURS:-26}"
AUTO_RECOVER="${AUTO_RECOVER:-0}"

tg() {
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || return 0
  local chat="${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"; [ -n "$chat" ] || return 0
  curl -s -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$chat" --data-urlencode text="$1" >/dev/null 2>&1 || true
}
in_window() { # honor OPERATING_WINDOW="HH:MM-HH:MM" if set; else always in-window
  [ -n "${OPERATING_WINDOW:-}" ] || return 0
  local now s e; now="$(date +%H%M)"; s="${OPERATING_WINDOW%-*}"; e="${OPERATING_WINDOW#*-}"
  now=$((10#$now)); s=$((10#${s/:/})); e=$((10#${e/:/}))
  [ "$now" -ge "$s" ] && [ "$now" -le "$e" ]
}
complete_today() {
  grep -q "$TODAY" journal.md 2>/dev/null && grep -q "^$TODAY," metrics.csv 2>/dev/null
}

# Healthy: today's trail exists → clear any alert flag and leave quietly.
if complete_today; then rm -f .watchdog-alerted 2>/dev/null; exit 0; fi

# Stale? Measure age of the last known-good run.
STALE=0
if [ -f .last-alive ]; then
  la="$(cat .last-alive 2>/dev/null)"
  last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$la" +%s 2>/dev/null || date -d "$la" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  [ "$last_epoch" -gt 0 ] && [ $(( (now_epoch - last_epoch) / 3600 )) -ge "$STALE_AFTER_HOURS" ] && STALE=1
else
  STALE=1   # never recorded a good run
fi
[ "$STALE" -eq 1 ] || exit 0
in_window || exit 0

# One alert per day (de-dup).
[ -f .watchdog-alerted ] && [ "$(cat .watchdog-alerted 2>/dev/null)" = "$TODAY" ] && exit 0
echo "$TODAY" > .watchdog-alerted

LASTRUN="$(tail -1 runs.csv 2>/dev/null)"
if [ "$AUTO_RECOVER" = "1" ] && [ ! -d .run.lock ]; then RECOVER="Triggering one catch-up run now."; else RECOVER="Run scripts/run-daily.sh to catch up."; fi
tg "🤖🔎 Watchdog: no COMPLETE daily run for ${TODAY} and the last healthy run is stale (>${STALE_AFTER_HOURS}h). Last runs.csv row: ${LASTRUN:-none}. state.md preserved. ${RECOVER}"

if [ "$AUTO_RECOVER" = "1" ] && [ ! -d .run.lock ]; then
  nohup scripts/run-daily.sh >/dev/null 2>&1 &
fi
exit 0
