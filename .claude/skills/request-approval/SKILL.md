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
   Viability: <for a build/submit gate: where this realistically ranks + does it pay a stranger inside the funding window — the go/no-go, from PUBLIC evidence>
   Ready artifact: <if you can produce it yourself ($0, in-sandbox): the packaged file's absolute path + sha256; else —>
   Approve spend: touch approvals/APPROVE · Human step: do it, then mark row #<n> done in state.md
   ```

2b. **Briefing completeness is a gate requirement, not a courtesy — and package before you ask.** The
   owner is spending their scarcest resource (attention, and sometimes their real name on a ToS) on the
   *briefing you attach*, so a one-sided "it's great!" ask is a defect. The `Viability:` line is REQUIRED
   for any gate that spends the owner's name/ToS/attention: state where this realistically lands from
   public evidence, not just the upside. And if the gated action is really just publishing an artifact
   you can produce yourself, PACKAGE it first (fill `Ready artifact:` with the path + checksum) so the
   human step is a 30-second upload — never an API key or a CLI command handed to the owner (see
   constitution rule 2, artifact-first hand-off).

3. **Send it** to the chat id in `TELEGRAM_OWNER_CHAT_ID` (fall back to `TELEGRAM_CHAT_ID` if unset)
   via the available Telegram tool. If the tool OR both chat-id env vars are missing, print the
   message, log the delivery failure under Blockers, and never invent or guess a chat id.
3b. **Announce it in the group** (`TELEGRAM_CHAT_ID`, if set and different from where the ping went):
   one line only — `⏸️ APPROVAL #<n> pending: <what, one clause> (gate: <gate>)`. The DM is the
   actionable ping; the group line is league transparency. Same content rules: no secrets, no
   card data, no counterparty PII. The chat stays write-only for you.
4. **Don't block on the answer.** Continue other non-gated work; check resolution on the next
   daily run. Spend approvals arrive as the `approvals/APPROVE` token — created EITHER by the owner
   running `touch approvals/APPROVE` on the runtime machine, OR by the owner replying `approve` in
   their DM, which `poll-approvals.sh` accepts **only** from the numeric `TELEGRAM_OWNER_CHAT_ID`
   (the group and all other DMs are ignored). You never read chat yourself; you only ever see the
   token appear. Human steps arrive as the state.md row marked done.
4b. **Close the loop publicly.** On the run that observes a resolution, post
   `✅ APPROVAL #<n> resolved: <what> — <spend approved / step done by owner>` to the group and
   append the row to `interventions.md` (owner fills minutes). Every ⏸️ eventually gets its ✅ —
   an unmatched ⏸️ older than 48h is a blocker worth flagging in the daily line.
5. **Escalation, capped:** a row still `waiting` after 24h earns ONE re-ping per day, prefixed
   `⏳ STILL WAITING`. Never more — the steering budget is ~1 intervention/day and nagging spends
   the owner's attention like the card spends money.
