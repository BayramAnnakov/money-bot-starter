#!/usr/bin/env bash
# watch.sh — human-readable view of what the bot did (or is doing right now).
# Turns the raw session transcript (logs/transcripts/*.jsonl) into a readable action stream.
#
#   scripts/watch.sh        # replay the most recent run
#   scripts/watch.sh -f     # follow the LIVE run as it happens (Ctrl-C to stop)
#   scripts/watch.sh <file> # a specific transcript
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1

FOLLOW=0; ARG="${1:-}"
[ "$ARG" = "-f" ] && { FOLLOW=1; ARG=""; }
T="${ARG:-$(ls -t logs/transcripts/*.jsonl 2>/dev/null | head -1)}"
[ -n "$T" ] && [ -f "$T" ] || { echo "no transcript found (has a run happened yet?)"; exit 0; }

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

FILTER='
  if .type=="assistant" then
    (.message.content[]? |
      if .type=="text" and ((.text|length)>0) then "  💭 " + (.text | gsub("\n";" ") | .[0:240])
      elif .type=="tool_use" then "→ " + .name + "  " + ((.input // {}) | tostring | gsub("\n";" ") | .[0:140])
      else empty end)
  elif .type=="user" then
    (.message.content[]? | select(.type=="tool_result") | select(.is_error==true) | "  ✗ tool error")
  elif .type=="result" then
    "◆ END: " + (.subtype // "?") + "  turns=" + ((.num_turns // 0)|tostring) + "  cost=$" + ((.total_cost_usd // 0)|tostring)
  else empty end'

echo "# watching: $T"
echo "# (💭 = the bot thinking · → = an action it took · ✗ = a tool error · ◆ = run end)"
echo
if [ "$FOLLOW" = "1" ]; then
  tail -n +1 -f "$T" | jq -rj --unbuffered "$FILTER, \"\n\"" 2>/dev/null
else
  jq -r "$FILTER" "$T" 2>/dev/null
fi
