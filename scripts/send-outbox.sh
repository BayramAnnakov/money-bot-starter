#!/usr/bin/env bash
# send-outbox.sh — deterministic Telegram sender. The AGENT never sends Telegram directly (it can't
# read the token — secrets discipline). It appends JSON lines to logs/telegram-outbox.jsonl:
#   {"to":"GROUP","text":"Day 0 …"}
#   {"to":"OWNER","text":"⚠️ APPROVAL…","buttons":[{"text":"✅ Approve #1","data":"approve:1"},{"text":"🚫 Deny #1","data":"deny:1"}]}
# This sender (called by the wrapper at end-of-run and by poll-approvals every few min) delivers them,
# attaches inline buttons when present, verifies delivery, self-heals a group→supergroup migration,
# and clears the outbox atomically. Token stays out of the agent entirely.
set -u
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
[ -f .env ] && set -a && . ./.env && set +a
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
mkdir -p logs
OUT=logs/telegram-outbox.jsonl
[ -s "$OUT" ] || exit 0

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
send_msg() { # send_msg <chat> <text> [reply_markup_json]
  if [ -n "${3:-}" ]; then
    curl -s -m 8 -X POST "${API}/sendMessage" -d chat_id="$1" --data-urlencode text="$2" --data-urlencode reply_markup="$3"
  else
    curl -s -m 8 -X POST "${API}/sendMessage" -d chat_id="$1" --data-urlencode text="$2"
  fi
}

PROC="${OUT}.proc.$$"
mv "$OUT" "$PROC" 2>/dev/null || exit 0   # atomic grab: new appends land in a fresh outbox
# `|| [ -n "$line" ]` so a final line with NO trailing newline is still processed (else it's silently dropped)
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  to=$(printf '%s' "$line"   | jq -r '.to   // "GROUP"' 2>/dev/null) || continue
  text=$(printf '%s' "$line" | jq -r '.text // empty'   2>/dev/null)
  [ -n "$text" ] || continue
  # optional inline keyboard (one row) from a "buttons":[{text,data},…] field
  markup=$(printf '%s' "$line" | jq -c 'if (.buttons|type)=="array" then {inline_keyboard:[[.buttons[]|{text:.text,callback_data:.data}]]} else empty end' 2>/dev/null)
  case "$to" in
    OWNER) chat="${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}" ;;
    *)     chat="${TELEGRAM_CHAT_ID:-}" ;;
  esac
  [ -n "$chat" ] || continue
  resp=$(send_msg "$chat" "$text" "$markup")
  ok=$(printf '%s' "$resp" | jq -r '.ok // false' 2>/dev/null)
  if [ "$ok" = "true" ]; then
    echo "$(date -u +%FT%TZ) OK -> ${to} (${chat}): $(printf '%s' "$text" | tr '\n' ' ' | head -c 60)" >> logs/outbox-sent.log
  else
    newchat=$(printf '%s' "$resp" | jq -r '.parameters.migrate_to_chat_id // empty' 2>/dev/null)
    desc=$(printf '%s' "$resp" | jq -r '.description // "no response"' 2>/dev/null)
    if [ -n "$newchat" ] && [ "$to" != "OWNER" ]; then
      # group -> supergroup migration: self-heal the chat id in .env and resend
      sed -i.bak "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=${newchat}|" .env 2>/dev/null && rm -f .env.bak
      TELEGRAM_CHAT_ID="$newchat"
      send_msg "$newchat" "$text" "$markup" >/dev/null 2>&1 || true
      echo "$(date -u +%FT%TZ) MIGRATED group -> updated .env TELEGRAM_CHAT_ID=${newchat}, resent" >> logs/outbox-sent.log
    else
      echo "$(date -u +%FT%TZ) FAILED -> ${to} (${chat}): ${desc}" >> logs/outbox-sent.log
    fi
  fi
done < "$PROC"
rm -f "$PROC"
exit 0
