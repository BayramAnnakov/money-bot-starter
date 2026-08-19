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
   Viability (REQUIRED whenever the gate spends the owner's name / a ToS signature / his attention): <the decision-relevant picture, NOT the flattering number — for a competition entry: where it would rank vs the public field, distance to a prize, and whether it can pay inside day 28. If you don't know, MEASURE it before firing this gate.>
   Ready artifact (submission/publish gates): <absolute path to the file YOU already packaged + its sha256 — the human step is "upload THIS file", never "run the CLI / give me a key">
   Blocking: <what can't proceed until resolved>
   Approve spend: touch approvals/APPROVE · Human step: do it, then mark row #<n> done in state.md
   Partial / conditional? Reply in DM "approve #<n>: <what you're granting>" or "deny #<n>: <why>" — a plain ✅ tap = FULL grant.
   ```

2b. **Briefing completeness is a gate requirement, not a courtesy — and package before you ask.** An approval that spends the owner's real name, a ToS signature, or his scarce attention MUST carry the decision-relevant picture (for a submission: competitive standing + can-it-pay-in-window), never just the favorable number — a one-sided "it's 7.3× better!" ping is a *defective gate*, because the owner cannot give informed consent to lend his name to a mid-table, can't-pay-in-window entry from the flattering half alone. If you don't yet know the standing, go measure it (public leaderboard / market) BEFORE firing. And for anything you can produce yourself — a competition tarball, a PR bundle, a file — package it FIRST (in the sandbox) and hand over the ready file + path + checksum; never an API key or a CLI command for the owner to run on your behalf.

3. **Queue it — you never send Telegram yourself** (no token access; secrets discipline). Run the
   allow-listed helper `scripts/outbox-add.sh` TWICE (it guarantees a clean one-line append — do NOT
   use the Write/Edit tool for the outbox):
   - Owner DM, WITH one-tap approve/deny buttons. **Encode the gate class in the button `data`** so the
     poller only mints the one-shot spend token for actual spends (a permission/human-step approval must
     NOT leave a live spend token):
     - **Spend gate** (a `> $X` money movement): `data":"approve:spend:<n>"` / `deny:spend:<n>`.
     - **Permission or human-step gate** (tool/permission per rule 7, account/KYC/ToS, outreach — anything
       that is NOT a spend): `data":"approve:<n>"` / `deny:<n>` (no `spend:` → no token minted; it resolves
       when the human edits settings / does the step).
     `scripts/outbox-add.sh '{"to":"OWNER","text":"<the ⚠️ APPROVAL ping above>","buttons":[{"text":"✅ Approve #<n>","data":"approve:spend:<n>  (or approve:<n> for a non-spend gate)"},{"text":"🚫 Deny #<n>","data":"deny:spend:<n>  (or deny:<n>)"}]}'`
   - Group transparency (no buttons):
     `scripts/outbox-add.sh '{"to":"GROUP","text":"⏸️ APPROVAL #<n> pending: <what, one clause> (gate: <gate>)"}'`
   The sender delivers OWNER→the owner DM (with the tap-to-approve button) and GROUP→the report chat.
   No secrets, no card data, no counterparty PII in either. Do NOT curl or read `.env`.
4. **Don't block on the answer.** Continue other non-gated work; check resolution on the next
   daily run. Spend approvals arrive as the `approvals/APPROVE` token — created EITHER by the owner
   running `touch approvals/APPROVE` on the runtime machine, OR by the owner replying `approve` in
   their DM, which `poll-approvals.sh` accepts **only** from the numeric `TELEGRAM_OWNER_CHAT_ID`
   (the group and all other DMs are ignored). You never read chat yourself; you only ever see the
   token appear. Human steps arrive as the state.md row marked done.
4b. **Close the loop.** Every run, reconcile `approvals/log.md` (the durable record of owner decisions,
   written by `poll-approvals.sh` on every ✅/🚫 tap and DM approval) against `interventions.md`. For each
   owner decision not yet reconciled:
   - **The group `✅/🚫 APPROVAL #<n> resolved` line is ALREADY POSTED** by the poller the instant the owner
     tapped — do NOT re-post it (that double-posts). Your job is only: append the row to `interventions.md`
     (owner fills minutes) AND act on the decision — an **approve** frees the gated step (a spend-approve also
     leaves the `approvals/APPROVE` token); a **deny** trips the kill-criterion of any bet blocked on it, so
     kill/shelve that bet and move to the runner-up, and drop the resolved row from state.md.
   - **A SCOPED owner NOTE** (an `OWNER DECISION w/ note` block in `approvals/log.md`) is AUTHORITATIVE and
     may be a PARTIAL grant: honor exactly the stated scope — do ONLY the granted part, and treat any part it
     withholds as still-gated (it is NOT granted even if a bare ✅ or `approvals/APPROVE` token also exists;
     the note's scope wins for that approval). For a **deny with a reason**, record the reason in `decisions.md`
     as the resolution (it's a scored input for the retro — the owner told you *why*), then kill/shelve the bet.
     Reflect the exact scope in the state.md row's status and in the blocked bet's plan before acting.
   - **Exception — a human step the owner did and marked done in state.md WITHOUT a poller record** (no
     `approvals/log.md` entry): then YOU post the group line via
     `scripts/outbox-add.sh '{"to":"GROUP","text":"✅ APPROVAL #<n> resolved: <what> — step done by owner"}'`.
   Every ⏸️ eventually gets its ✅/🚫 — an unmatched ⏸️ older than 48h is a blocker worth flagging in the daily line.
5. **Escalation, capped:** a row still `waiting` after 24h earns ONE re-ping per day, prefixed
   `⏳ STILL WAITING`. Never more — the steering budget is ~1 intervention/day and nagging spends
   the owner's attention like the card spends money.
