#!/bin/bash
# spend-gate.sh — PreToolUse hook (Bash matcher): tier-2 enforcement.
# Blocks money-touching shell commands unless a one-time approval token exists.
# Tier 1 is the constitution (advice); tier 3 is the card limit (physics). This is the speed bump.
#
# Owner grants exactly ONE gated execution:   touch approvals/APPROVE
# Consumption is logged to approvals/log.md. While charter.md still contains its
# PLACEHOLDER banner, payment-pattern commands are blocked unconditionally (shadow mode).

set -u

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
# jq missing or schema drift: fall back to scanning the raw payload
[ -z "$CMD" ] && CMD="$INPUT"

# Conservative payment patterns. False positives are cheap (the agent asks the owner);
# false negatives are what the card limit is for.
PATTERN='api\.stripe\.com|stripe .*(charge|payment|payout|checkout|invoice)|payment[-_ ]?(intent|link)|privacy\.com|/v1/(charges|payouts|transfers)|polymarket|usdc|checkout\.'

printf '%s' "$CMD" | grep -qiE "$PATTERN" || exit 0

# MONEY_BOT_ROOT override exists for testing the hook outside a live session
REPO="${MONEY_BOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

if grep -q "PLACEHOLDER" "$REPO/charter.md" 2>/dev/null; then
  echo "BLOCKED (shadow mode): charter.md is not frozen — zero real transactions. Log the intended spend in decisions.md as a plan instead." >&2
  exit 2
fi

TOKEN="$REPO/approvals/APPROVE"
if [ -f "$TOKEN" ]; then
  {
    echo ""
    echo "## $(date -u +%Y-%m-%dT%H:%M:%SZ) — approval consumed"
    echo '```'
    printf '%s\n' "$CMD" | head -5
    echo '```'
  } >> "$REPO/approvals/log.md"
  rm -f "$TOKEN"
  exit 0
fi

echo "BLOCKED (spend gate): this command matches a payment pattern and no approval token exists. Write the request into state.md pending-approvals and ask the owner. The owner grants ONE execution with: touch approvals/APPROVE" >&2
exit 2
