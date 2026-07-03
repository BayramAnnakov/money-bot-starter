---
name: daily-report
description: Post the money bot's daily one-line P&L update to the AI Natives Telegram group. Use at the end of every daily loop run, or when the user asks to "post the daily report".
---

# Daily Report

1. Read `ledger.md` (running totals) and today's entry in `decisions.md`.
2. Compose exactly one line:
   `Day N: balance $A | revenue $B | today: <one action, ≤10 words> | next: <one action, ≤10 words>`
   - N = days since experiment start (see ledger start date)
   - balance = card balance after today's transactions
   - revenue = cumulative verified revenue received
3. Post it to the `edu-ai-natives` Telegram group (chat ID `3727652888`) via the available Telegram tool/MCP. If no Telegram tool is available in this environment, print the line and ask the human to paste it.
4. Once a week (before the meetup), append the 5-line weekly report from CLAUDE.md §Reporting instead of the one-liner.

Never include card numbers, API keys, counterparty personal data, or login credentials in a report.
