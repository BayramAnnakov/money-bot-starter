#!/usr/bin/env bash
# outbox-add.sh — the ONLY sanctioned way for the agent to queue a Telegram message.
# Appends ONE compact JSON object (arg $1, or stdin) as a single line to logs/telegram-outbox.jsonl.
# Using this (allow-listed) instead of the Write/Edit tool guarantees a trailing newline and an atomic
# O_APPEND write: no lost final line, no read-modify-write race, no accidental multi-line JSON.
#   scripts/outbox-add.sh '{"to":"GROUP","text":"Day 1 …"}'
#   scripts/outbox-add.sh '{"to":"OWNER","text":"⚠️ …","buttons":[{"text":"✅ Approve #1","data":"approve:1"}]}'
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
mkdir -p logs
json="${1:-$(cat)}"
[ -n "$json" ] || { echo "usage: outbox-add.sh '<json with a .text field>'" >&2; exit 1; }
# validate: must be one JSON object with a non-empty .text; compact to a single line
compact=$(printf '%s' "$json" | jq -c 'select(.text|type=="string" and (.|length>0))' 2>/dev/null)
if [ -z "$compact" ]; then
  echo "$(date -u +%FT%TZ) DEAD-LETTER (invalid outbox json): $(printf '%s' "$json" | tr '\n' ' ' | head -c 120)" >> logs/outbox-deadletter.log
  echo "outbox-add: invalid JSON or missing .text — dead-lettered, not queued" >&2
  exit 1
fi
printf '%s\n' "$compact" >> logs/telegram-outbox.jsonl
