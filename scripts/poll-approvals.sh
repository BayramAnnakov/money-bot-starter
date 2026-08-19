#!/usr/bin/env bash
# poll-approvals.sh — owner-only approval channel. Deterministic, NO LLM in the loop.
#
# Accepts an approval ONLY from the owner's NUMERIC id (TELEGRAM_OWNER_CHAT_ID) — via a DM "approve"
# OR a tap on the inline ✅ Approve button. Every other sender — the report GROUP, any other DM, a
# button tapped by anyone else — fails the auth gate and is ignored + logged. Auth is by numeric id;
# usernames/display names are spoofable and NEVER trusted. Even from the owner, only a strict "approve"
# grammar mints the token (the card limit is the backstop). Also flushes the agent's Telegram outbox.
#
# SCOPED / EXPLAINED decisions (added 2026-07-25): a bare "approve" is binary and can't say "only part
# (b)". So if the owner's DM STARTS with an approve/deny verb but carries extra words (e.g. "deny 4:
# base rate too low" or "approve 4 — proposal only, no KYC"), it is recorded VERBATIM as a bounded owner
# NOTE bound to that approval and mints NO spend token; the agent reads the note next run and acts within
# the stated scope. The shell only authenticates + records; the LLM interprets the natural-language scope.
# This does NOT turn the DM into a general command channel — a note only ever scopes/explains an approval
# the agent itself opened, never issues a free-standing command, and never overrides a gate or rule.
#
# This bot's token must have NO other getUpdates/webhook consumer (Telegram delivers each update once).
# Cron (in the operating window):  */3 * * * *  /path/to/money-bot/scripts/poll-approvals.sh
set -u
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
[ -f .env ] && set -a && . ./.env && set +a
mkdir -p logs

[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "$(date -u +%FT%TZ) poll-approvals: jq missing — cannot parse safely, refusing" >> logs/approvals.log; exit 0; }

# flush any queued agent->Telegram messages every cycle (so mid-run approval pings go out within minutes)
bash "$(cd "$(dirname "$0")" && pwd)/send-outbox.sh" >/dev/null 2>&1 || true

# Fail CLOSED: with no owner id there is no one to authenticate, so accept nothing.
if [ -z "${TELEGRAM_OWNER_CHAT_ID:-}" ]; then
  echo "$(date -u +%FT%TZ) poll-approvals: TELEGRAM_OWNER_CHAT_ID unset — refusing ALL approvals" >> logs/approvals.log
  exit 0
fi

OFFSET_FILE=.tg-offset
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "")

# allowed_updates = ["message","callback_query"] (button taps)
resp=$(curl -s -m 12 "${API}/getUpdates?timeout=0&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D${offset:+&offset=$offset}")
echo "$resp" | jq -e '.ok==true' >/dev/null 2>&1 || exit 0

# First run (no stored offset): prime past the current backlog WITHOUT acting, so a stale "approve"
# from before launch can never be replayed.
if [ -z "$offset" ]; then
  ids=$(echo "$resp" | jq -rc '[.result[].update_id]')
  maxid=$(echo "$resp" | jq -r '[.result[].update_id] | max // 0')
  # Priming DROPS the whole backlog without acting (anti-replay). That is safe for pre-launch noise
  # but would silently eat a real owner approval tapped in the gap before the first poll — so surface
  # it loudly. In normal operation the freeze step seeds .tg-offset, so this branch never runs live.
  ownerhit=$(echo "$resp" | jq -r --arg o "$TELEGRAM_OWNER_CHAT_ID" '[.result[] | select(((.callback_query.from.id|tostring)==$o) or ((.message.chat.id|tostring)==$o))] | length')
  case "$maxid" in ''|null|0) echo 0 > "$OFFSET_FILE" ;; *) echo $((maxid+1)) > "$OFFSET_FILE" ;; esac
  echo "$(date -u +%FT%TZ) poll-approvals: primed past backlog (ids=$ids owner-updates-skipped=$ownerhit) — NO action on first run" >> logs/approvals.log
  [ "${ownerhit:-0}" -gt 0 ] 2>/dev/null && echo "$(date -u +%FT%TZ) poll-approvals: WARNING — skipped $ownerhit owner-originated update(s) during prime; if you tapped Approve just now, re-tap (offset is now seeded)." >> logs/approvals.log
  exit 0
fi

mint_token() { # mint_token <how> <raw>
  touch approvals/APPROVE
  { echo ""; echo "## $(date -u +%FT%TZ) — OWNER approval ($1)"; echo "> $2"; } >> approvals/log.md
  echo "$(date -u +%FT%TZ) OWNER approval via $1 -> approvals/APPROVE created" >> logs/approvals.log
}
ack_cb() { curl -s -m 8 -X POST "${API}/answerCallbackQuery" -d callback_query_id="$1" ${2:+--data-urlencode text="$2"} >/dev/null 2>&1 || true; }
edit_msg() { [ -n "${2:-}" ] || return 0; curl -s -m 8 -X POST "${API}/editMessageText" -d chat_id="$1" -d message_id="$2" --data-urlencode text="$3" >/dev/null 2>&1 || true; }
# Instant group transparency on a decision — the league sees the resolution the moment the owner taps,
# not on the next agent run. The agent then only does the bookkeeping (interventions.md + state.md),
# it does NOT re-post (see request-approval skill 4b).
group_line() { [ -n "${TELEGRAM_CHAT_ID:-}" ] || return 0; curl -s -m 8 -X POST "${API}/sendMessage" -d chat_id="${TELEGRAM_CHAT_ID}" --data-urlencode text="$1" >/dev/null 2>&1 || true; }

echo "$resp" | jq -c '.result[]?' | while IFS= read -r upd; do
  uid=$(printf '%s' "$upd" | jq -r '.update_id')
  echo $((uid+1)) > "$OFFSET_FILE"     # advance so we never re-process, even when we skip an update

  # --- inline button tap (callback_query) ---
  cbid=$(printf '%s' "$upd" | jq -r '.callback_query.id // empty')
  if [ -n "$cbid" ]; then
    cbfrom=$(printf '%s' "$upd" | jq -r '.callback_query.from.id // empty')
    cbdata=$(printf '%s' "$upd" | jq -r '.callback_query.data // empty')
    cbmid=$(printf '%s' "$upd" | jq -r '.callback_query.message.message_id // empty')
    cbchat=$(printf '%s' "$upd" | jq -r '.callback_query.message.chat.id // empty')
    if [ "$cbfrom" != "$TELEGRAM_OWNER_CHAT_ID" ]; then
      echo "$(date -u +%FT%TZ) IGNORED button tap from non-owner ${cbfrom}" >> logs/approvals.log
      ack_cb "$cbid" "Only the owner can approve."
    else
      case "$cbdata" in
        approve:spend:*) # SPEND approval → mint the one-shot token the spend-gate consumes
                  mint_token "button" "$cbdata"; ack_cb "$cbid" "✅ Approved (spend token issued)."; edit_msg "$cbchat" "$cbmid" "✅ Approved by owner — the next gated SPEND runs once."; group_line "✅ APPROVAL #${cbdata##*:} resolved — approved by owner." ;;
        approve*) # PERMISSION / human-step approval → record + notify, but NO spend token (resolves via settings/human action)
                  { echo ""; echo "## $(date -u +%FT%TZ) — OWNER approval, NON-SPEND (${cbdata})"; echo "> resolves via settings edit / human step; no spend token minted"; } >> approvals/log.md
                  echo "$(date -u +%FT%TZ) OWNER approved (non-spend) via button: ${cbdata}" >> logs/approvals.log
                  ack_cb "$cbid" "✅ Approved."; edit_msg "$cbchat" "$cbmid" "✅ Approved by owner — resolves via a settings/human step (no spend token)."; group_line "✅ APPROVAL #${cbdata##*:} resolved — approved by owner." ;;
        deny*)    echo "$(date -u +%FT%TZ) OWNER denied via button: ${cbdata}" >> logs/approvals.log
                  { echo ""; echo "## $(date -u +%FT%TZ) — OWNER DENIAL (button)"; echo "> ${cbdata}"; } >> approvals/log.md
                  ack_cb "$cbid" "🚫 Denied."; edit_msg "$cbchat" "$cbmid" "🚫 Denied by owner."; group_line "🚫 APPROVAL #${cbdata##*:} resolved — denied by owner." ;;
        *)        ack_cb "$cbid" "" ;;
      esac
    fi
    continue
  fi

  # --- text message ---
  chat=$(printf '%s' "$upd" | jq -r '.message.chat.id // empty')
  text=$(printf '%s' "$upd" | jq -r '.message.text // empty')
  [ -n "$chat" ] || continue
  # THE AUTH GATE — only the owner's numeric DM id. Group + every other DM stop here.
  if [ "$chat" != "$TELEGRAM_OWNER_CHAT_ID" ]; then
    echo "$(date -u +%FT%TZ) IGNORED message from non-owner chat ${chat}" >> logs/approvals.log
    continue
  fi
  # Grammar, in order of specificity:
  #   1) BARE approval → mint the one-shot spend token (verb [+ #id] and NOTHING else). Unchanged.
  #   2) SCOPED/EXPLAINED decision → a bounded owner NOTE, NO token: a deny/reject (reason optional)
  #      OR an approve/grant followed by extra words. Recorded verbatim; the agent reads it next run
  #      and acts within the stated scope. So 'approved? not yet' still does NOT mint (it isn't verb-first).
  #   3) anything else → ignored.
  norm=$(printf '%s' "$text" | tr 'A-Z' 'a-z' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  ack_owner() { curl -s -m 8 -X POST "${API}/sendMessage" -d chat_id="${TELEGRAM_OWNER_CHAT_ID}" --data-urlencode text="$1" >/dev/null 2>&1 || true; }
  if [[ "$norm" =~ ^(/?approve(d)?|granted)([[:space:]]*#?[a-z0-9_-]+)?$ ]]; then
    mint_token "DM" "$text"
    ack_owner "✅ Approval received — the next gated command will execute once."
  elif [[ "$norm" =~ ^(deny|denied|denies|decline|declined|reject|rejected)([[:space:]#].*)?$ ]] || [[ "$norm" =~ ^(/?approve(d|s)?|approving|grant|granted|grants|granting)[[:space:]#].+$ ]]; then
    { echo ""; echo "## $(date -u +%FT%TZ) — OWNER DECISION w/ note (DM, numeric-id authed) — SCOPED, NO spend token"; echo "> ${text}"; } >> approvals/log.md
    echo "$(date -u +%FT%TZ) OWNER scoped decision via DM (no token): ${text}" >> logs/approvals.log
    ack_owner "📝 Recorded your scoped decision — the agent reads it next run and acts within that scope (no blanket spend token minted). For a plain full-spend yes, reply just 'approve'."
  else
    echo "$(date -u +%FT%TZ) owner DM (not an approval command, ignored): ${text}" >> logs/approvals.log
  fi
done
exit 0
