---
name: daily-report
description: Post the money bot's daily one-line P&L update to the group Telegram chat. Use at the end of every daily loop run, or when the user asks to "post the daily report".
---

# Daily Report

1. Read `state.md` (snapshot) and today's entry in `decisions.md`.
2. Compose exactly one line:
   `Day N: balance $A | revenue: stranger $S / insider $I | today: <one action, ≤10 words> | next: <one action, ≤10 words>`
   - N = days since experiment start (start date is in `ledger.md`; if unfilled, say "Day ?" and flag it)
   - balance = card balance after today's transactions
   - stranger/insider split per the ledger's provenance tags — the headline must never blend them (spectator dollars masquerading as traction was AI Village's biggest measurement gap)
   - In shadow mode, prefix the line with `[SHADOW]`
3. Post it to the Telegram chat whose ID is in the `TELEGRAM_CHAT_ID` env var (via the available Telegram tool/MCP). Do NOT hardcode a chat ID. If the env var or tool is missing, print the line and ask the human to paste it.
4. Once a week (before the meetup), also append the agent's 5-line weekly report (per CLAUDE.md §Reporting) to `decisions.md` and post it to the same chat. The GROUP's retro lives in `retro.md` and is written by humans, not you.

All numbers you report are agent-reported and unverified until the weekly human reconciliation (`retro.md` step 1).
Never include card numbers, API keys, counterparty personal data, or login credentials in a report.
