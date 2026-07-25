#!/usr/bin/env bash
# autonomy-guard.sh — Claude Code STOP hook. Keeps an autonomous run from quitting before it has
# done real work AND left the required trail. It is the INTRA-session complement to run-daily.sh's
# inter-session auto-resume: this fires the moment the agent tries to end its turn.
#
# Scope: fires ONLY inside a wrapper-managed run — run-daily.sh stamps .session-started (fresh) and
# .session-mode. For manual/interactive sessions (no fresh marker) the hook is DORMANT (exit 0).
#
# Contract by mode:
#   daily — today's journal "## Day … <YYYY-MM-DD>" header AND today's metrics.csv row must exist.
#   work  — state.md must have been advanced this session (mtime newer than .session-started).
#
# Safety (this guards a MONEY bot — a bad loop burns API budget):
#   • Bounded: blocks at most STOP_MAX_NUDGES times per run (logs/.stop-nudges, reset by the wrapper),
#     then ALLOWS the stop — the wrapper's next-run resume is the outer net. Well under Claude Code's
#     own 8-consecutive-block hard cap.
#   • Fails OPEN: any error, missing jq, or unparseable input → exit 0 (never trap the agent).
#   • Never sees or needs the Telegram token; does not source .env.
set -u

ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)" || exit 0
cd "$ROOT" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null)"
command -v jq >/dev/null 2>&1 || exit 0            # can't parse safely → allow stop

# Only act inside a managed run that started recently (guards manual/interactive sessions).
[ -f .session-started ] || exit 0
[ -n "$(find .session-started -mmin -90 2>/dev/null)" ] || exit 0   # stale marker → not an active run

active="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"
mode="$(cat .session-mode 2>/dev/null || echo daily)"

MAXN="${STOP_MAX_NUDGES:-3}"; case "$MAXN" in ''|*[!0-9]*) MAXN=3 ;; esac
CF="logs/.stop-nudges"; mkdir -p logs 2>/dev/null
n="$(cat "$CF" 2>/dev/null || echo 0)"; case "$n" in ''|*[!0-9]*) n=0 ;; esac

contract_met() {
  if [ "$mode" = "work" ]; then
    [ -n "$(find state.md -newer .session-started 2>/dev/null)" ] && return 0 || return 1
  fi
  local today; today="$(date +%F)"
  grep -qE "^## Day .*$today" journal.md 2>/dev/null || return 1
  grep -q "^$today," metrics.csv 2>/dev/null || return 1
  return 0
}

if contract_met; then
  : > "$CF" 2>/dev/null                              # reset for the next run
  exit 0
fi

# Contract not met — nudge, but stay bounded.
if [ "$n" -ge "$MAXN" ]; then
  echo "$(date -u +%FT%TZ) autonomy-guard: contract still unmet after $n nudges (mode=$mode, active=$active) — allowing stop; wrapper resumes next run" >> logs/daily.err 2>/dev/null || true
  exit 0
fi
echo $((n+1)) > "$CF" 2>/dev/null

if [ "$mode" = "work" ]; then
  reason="STOP BLOCKED (work session): you have not advanced state.md this run. Take the top NON-GATED action from state.md and make concrete progress on an open bounty/entry (clone/fork into work/<repo> per rule 9, implement, run its tests), then CHECKPOINT it in state.md: target repo, your fork URL, branch, what's done, the exact next step, any blocker. If every remaining action is blocked on a human/approval gate and there is genuinely no non-gated work left, write that one line into state.md's Blockers and you may stop."
else
  reason="STOP BLOCKED (daily run): today's trail is incomplete. Before ending you MUST finish the loop: (1) reconcile the ledger from the REAL dashboards, (2) rewrite state.md, (3) write today's journal entry with a '## Day N — $(date +%F)' header, (4) append today's row to metrics.csv (frozen schema; unknown = empty cell, never a guess), (5) queue the daily report via scripts/outbox-add.sh. A run that leaves no trail didn't happen. If the work itself is blocked on a gate, still COMPLETE the trail recording the blocker, then you may stop."
fi
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
