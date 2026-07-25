#!/usr/bin/env bash
# check-liveness.sh — independent watchdog. NO `claude` dependency, so it survives the exact
# failures the daily loop can't report (crash, turn-limit stop, cron that never fired while the
# machine was on). It also probes the SANDBOX ENGINE (Docker/OrbStack): a run can "complete" while
# the engine is down, so sandbox work silently skips — a failure the run-staleness check can't see.
# Cron it a few times inside the operating window. See OBSERVABILITY.md §Liveness.
#
# Cron:  0 12,15,18 * * *  /path/to/money-bot/scripts/check-liveness.sh
set -u
export PATH="$HOME/.local/bin:$HOME/.orbstack/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
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
  grep -qE "^## Day .*$TODAY" journal.md 2>/dev/null && grep -q "^$TODAY," metrics.csv 2>/dev/null
}

# --- Sandbox engine reachability (only if the OPTIONAL sandbox module is enabled) --------------------
# A run can COMPLETE while the Docker/OrbStack engine is DOWN: every scripts/sandbox-run.sh then exits
# 127, so sandbox dev work silently SKIPS while complete_today() stays true — a failure the staleness
# logic below is structurally blind to. So probe the engine on its own, but only inside the operating
# window (the sandbox only matters when the bot runs). Gated on SANDBOX_ENABLED so a bot that never
# opted into the sandbox module never gets a false "engine down" alert. Runs regardless of whether
# today's run completed, and does NOT exit — it falls through to the run-staleness check. Primary fix
# for the reboot case is OrbStack `app.start_at_login=true` (or Docker Desktop "start at login"); this
# is the belt-and-braces for a mid-day engine crash or a reboot with no login session.
if [ "${SANDBOX_ENABLED:-0}" = "1" ] && in_window; then
  if docker info >/dev/null 2>&1; then
    rm -f .docker-alerted 2>/dev/null              # engine healthy → clear the flag
  else
    # Optional self-heal, same AUTO_RECOVER gate as the run-catchup below. `arch -arm64` avoids the
    # "must not be running under Rosetta" launch error seen from some shells; best-effort, never fatal.
    if [ "$AUTO_RECOVER" = "1" ] && command -v orb >/dev/null 2>&1; then
      arch -arm64 orb start >/dev/null 2>&1 || orb start >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5 6; do docker info >/dev/null 2>&1 && break; sleep 3; done
    fi
    if docker info >/dev/null 2>&1; then
      rm -f .docker-alerted 2>/dev/null            # recovered by the self-heal → clear the flag
    elif [ "$(cat .docker-alerted 2>/dev/null)" != "$TODAY" ]; then
      echo "$TODAY" > .docker-alerted              # one alert per day for THIS distinct condition
      tg "🤖🐳 Watchdog: Docker/OrbStack engine unreachable at $(date +%H:%M) (inside operating window). scripts/sandbox-run.sh will exit 127, so ARC/bounty sandbox work SILENTLY SKIPS even though the daily run still 'completes'. Fix: start OrbStack (or 'orb start'). Common cause: a reboot where the VM didn't auto-start."
    fi
  fi
fi

# Healthy: today's trail exists → clear any alert flag and leave quietly.
if complete_today; then rm -f .watchdog-alerted 2>/dev/null; exit 0; fi

# Stale? Measure age of the last known-good run.
STALE=0
if [ -f .last-alive ]; then
  la="$(cat .last-alive 2>/dev/null)"
  # .last-alive is UTC (trailing Z) — parse AS UTC (TZ=UTC0), or BSD date reads it as local and skews staleness.
  last_epoch=$(TZ=UTC0 date -j -f "%Y-%m-%dT%H:%M:%SZ" "$la" +%s 2>/dev/null || date -u -d "$la" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  if [ "$last_epoch" -le 0 ]; then
    STALE=1   # unparseable/corrupt heartbeat reads as DEAD, never as alive
  elif [ $(( (now_epoch - last_epoch) / 3600 )) -ge "$STALE_AFTER_HOURS" ]; then
    STALE=1
  fi
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
