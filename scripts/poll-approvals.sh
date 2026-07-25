#!/usr/bin/env bash
# poll-approvals.sh — owner-only DM approval channel. Deterministic, NO LLM in the loop.
#
# Accepts an approval ONLY from the owner's NUMERIC chat id (TELEGRAM_OWNER_CHAT_ID). Every other
# sender — the report GROUP (a negative chat id) and any other DM — fails the auth gate and is
# gracefully ignored + logged. Auth is by numeric id; usernames and display names are spoofable and
# are NEVER trusted. Even from the owner, ONLY a narrow "approve" grammar is honored; any other text
# is logged, not executed (so a compromised owner account can at most approve — bounded by the card).
# The token still feeds the spend-gate hook (one gated execution); the card limit is the backstop.
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

# Fail CLOSED: with no owner id there is no one to authenticate, so accept nothing.
if [ -z "${TELEGRAM_OWNER_CHAT_ID:-}" ]; then
  echo "$(date -u +%FT%TZ) poll-approvals: TELEGRAM_OWNER_CHAT_ID unset — refusing ALL DM approvals" >> logs/approvals.log
  exit 0
fi

OFFSET_FILE=.tg-offset
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "")

resp=$(curl -s -m 12 "${API}/getUpdates?timeout=0&allowed_updates=%5B%22message%22%5D${offset:+&offset=$offset}")
echo "$resp" | jq -e '.ok==true' >/dev/null 2>&1 || exit 0

# First run (no stored offset): prime past the current backlog WITHOUT acting, so a stale "approve"
# from before launch can never be replayed.
if [ -z "$offset" ]; then
  maxid=$(echo "$resp" | jq -r '[.result[].update_id] | max // 0')
  case "$maxid" in ''|null|0) echo 0 > "$OFFSET_FILE" ;; *) echo $((maxid+1)) > "$OFFSET_FILE" ;; esac
  echo "$(date -u +%FT%TZ) poll-approvals: primed offset past backlog (no action on first run)" >> logs/approvals.log
  exit 0
fi

echo "$resp" | jq -c '.result[]?' | while IFS= read -r upd; do
  uid=$(printf '%s' "$upd" | jq -r '.update_id')
  echo $((uid+1)) > "$OFFSET_FILE"     # advance so we never re-process, even when we skip a message
  chat=$(printf '%s' "$upd" | jq -r '.message.chat.id // empty')
  text=$(printf '%s' "$upd" | jq -r '.message.text // empty')
  [ -n "$chat" ] || continue

  # THE AUTH GATE — only the owner's numeric DM id. The group (negative id) and every other DM stop here.
  if [ "$chat" != "$TELEGRAM_OWNER_CHAT_ID" ]; then
    echo "$(date -u +%FT%TZ) IGNORED message from non-owner chat ${chat} (group/other DMs are never commands)" >> logs/approvals.log
    continue
  fi

  # Grammar, in order of specificity:
  #   1) BARE approval → mint the one-shot spend token (verb [+ #id] and NOTHING else). Strict on purpose.
  #   2) SCOPED/EXPLAINED decision → a bounded owner NOTE, NO token: a deny/reject (reason optional) OR an
  #      approve/grant followed by extra words (e.g. "approve 4: proposal only, no KYC"). Recorded verbatim;
  #      the agent reads it next run and acts within the stated scope. The shell authenticates + records;
  #      the LLM interprets the natural-language scope. Still not a general command channel — a note only
  #      ever scopes/explains an approval the agent itself opened.
  norm=$(printf '%s' "$text" | tr 'A-Z' 'a-z' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  ack_owner() { curl -s -m 8 -X POST "${API}/sendMessage" -d chat_id="${TELEGRAM_OWNER_CHAT_ID}" --data-urlencode text="$1" >/dev/null 2>&1 || true; }
  if [[ "$norm" =~ ^(/?approve(d)?|granted)([[:space:]]*#?[a-z0-9_-]+)?$ ]]; then
    touch approvals/APPROVE
    { echo ""; echo "## $(date -u +%FT%TZ) — OWNER DM approval"; echo "> ${text}"; } >> approvals/log.md
    echo "$(date -u +%FT%TZ) OWNER approval via DM -> approvals/APPROVE created" >> logs/approvals.log
    ack_owner "✅ Approval received — the next gated command will execute once."
  elif [[ "$norm" =~ ^(deny|denied|denies|decline|declined|reject|rejected)([[:space:]#].*)?$ ]] || [[ "$norm" =~ ^(/?approve(d|s)?|approving|grant|granted|grants|granting)[[:space:]#].+$ ]]; then
    { echo ""; echo "## $(date -u +%FT%TZ) — OWNER DECISION w/ note (DM, numeric-id authed) — SCOPED, NO spend token"; echo "> ${text}"; } >> approvals/log.md
    echo "$(date -u +%FT%TZ) OWNER scoped decision via DM (no token): ${text}" >> logs/approvals.log
    ack_owner "📝 Recorded your scoped decision — the agent reads it next run and acts within that scope (no blanket spend token). For a plain full-spend yes, reply just 'approve'."
  else
    echo "$(date -u +%FT%TZ) owner DM (not an approval command, ignored): ${text}" >> logs/approvals.log
  fi
done
exit 0
