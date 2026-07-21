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

# The agent may NEVER mint its own approval token — only the human runs `touch approvals/APPROVE`
# in their own shell (which the hook never sees). Any agent Bash touching that path is a
# self-approval attempt: block unconditionally, before the payment check.
if printf '%s' "$CMD" | grep -qE 'approvals/APPROVE'; then
  echo "BLOCKED: the agent may not create or modify the approval token. Only the owner runs 'touch approvals/APPROVE'; request it via the request-approval skill." >&2
  exit 2
fi

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
  # Transparency (best-effort, never affects the verdict): announce consumption in the group chat
  if [ -f "$REPO/.env" ]; then
    TG_TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$REPO/.env" | head -1 | cut -d= -f2- | tr -d ' "')
    TG_CHAT=$(grep -E '^TELEGRAM_CHAT_ID=' "$REPO/.env" | head -1 | cut -d= -f2- | tr -d ' "')
    if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT" ]; then
      curl -s -m 5 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT}" \
        -d text="✅ Spend-approval token consumed (one gated command executed — see approvals/log.md)" \
        >/dev/null 2>&1 || true
    fi
  fi
  exit 0
fi

echo "BLOCKED (spend gate): this command matches a payment pattern and no approval token exists. Write the request into state.md pending-approvals and ask the owner. The owner grants ONE execution with: touch approvals/APPROVE" >&2
exit 2
