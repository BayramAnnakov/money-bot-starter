---
name: request-approval
description: Push an approval request to the bot's owner via Telegram and queue it in state.md. Use whenever a HITL gate fires — gated spend, human-platform account, ToS acceptance, irreversible/public action, cold outreach, CAPTCHA/3DS/verification handoff.
---

# Request Approval (push, don't just queue)

A queued approval nobody sees is a stalled bot. Every gate hit gets BOTH: a row in `state.md`
AND a Telegram ping to the owner. You still never read any chat — resolution comes back to you
through the repo (token file or an updated row), not through messages.

## Steps

1. **Queue it:** append a row to `state.md` → *Pending human approvals* with the next free `#`,
   what needs approval, which gate fired, status `waiting`.
2. **Compose the ping** (one message, no secrets, no card numbers, no counterparty PII):

   ```
   ⚠️ APPROVAL #<n> — <bot name>
   What: <one sentence>
   Gate: <spend >$X / account / ToS / irreversible / outreach / CAPTCHA-3DS>  Amount: $<x or —>
   Blocking: <what can't proceed until resolved>
   Approve spend: touch approvals/APPROVE · Human step: do it, then mark row #<n> done in state.md
   ```

3. **Send it** to the chat id in `TELEGRAM_OWNER_CHAT_ID` (fall back to `TELEGRAM_CHAT_ID` if unset)
   via the available Telegram tool. If no Telegram tool is available, print the message and log the
   delivery failure under Blockers.
4. **Don't block on the answer.** Continue other non-gated work; check resolution on the next
   daily run (spend approvals arrive as the `approvals/APPROVE` token; human steps arrive as the
   row marked done).
5. **Escalation, capped:** a row still `waiting` after 24h earns ONE re-ping per day, prefixed
   `⏳ STILL WAITING`. Never more — the steering budget is ~1 intervention/day and nagging spends
   the owner's attention like the card spends money.
