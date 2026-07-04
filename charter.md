# Experiment Charter v1.0

> PLACEHOLDER — this bot's owner fills the charter via the `adopt-bot` skill during prep week,
> then FREEZES it at launch by deleting this banner block. Deleting the banner IS the freeze act.
> Until then the agent runs in SHADOW MODE ONLY (plans, no spending) — enforced by the daily-loop
> step 0, the spend-gate hook, and the fact that no funded card is attached.

The charter defines: avenue, budget + card rules, runtime + compute cost owner, HITL gates, disclosure policy, reporting cadence, pivot trigger (default: no stranger-dollar by day 10 → switch to the runner-up avenue), kill-switch keyholders, the pinned model (don't swap mid-experiment), operating window, and the week-5 write-up commitment.

## Kickoff decisions (2026-07-03) — league-wide, binding for every bot

Decided live at the Build Session; individual charters inherit these unless the group amends them at a weekly meetup:

- **League mode.** Every participant runs their OWN bot from this template: own idea, own budget, own card, own Telegram chat, own P&L. The league compares bots weekly; `REGISTRY.md` upstream is the roster.
- **Budget: $100** per bot, on a card with a HARD limit at card level (prompt budgets are advice; card limits are physics).
- **No top-ups.** Topping up = leaving the league (the bot may keep running for learning, outside the standings). Budget hit zero and the bot can still act? Owner's call to let it try to earn from nothing — that's allowed; adding money is not.
- **Human gates:** any single spend > **$20**; account creation on human platforms (KYC, banks, Google, marketplaces — agent-native services on the approved list may be self-registered); ToS acceptance under a person's name; anything irreversible or public under a member's real identity; cold outreach to real humans.
- **Disclosure:** the bot always says it's a bot.
- **Compute split:** the agent's own reasoning runs on the owner's existing LLM subscription (not counted); the owner's pre-existing service subscriptions are free to use and listed below; any NEW external-service spend (generation APIs, paid data, credits) comes off the $100 through the ledger.
- **Reporting:** daily one-liner to the bot's own Telegram chat (write-only for the agent — it never reads the chat); weekly review at the meetup.
- **Steering budget:** ~1 human intervention per day max, every one logged (`retro.md` counts them). Week 1 is exempt — signups and setup cluster there.
- **Anti-passivity:** a bot that just preserves capital is disqualified. At least one real earning attempt per week.
- **No unfair distribution:** owners don't lend the bot their own audience (channels, follower bases) — the bot builds its own surfaces. Insider revenue is tagged and doesn't count toward the milestone.
- **KYC + taxes:** on the named owner.
- **Duration:** 4 weeks from launch (launch target 2026-07-10; this week is prep). Week 5: public write-up regardless of outcome.
- **On the table (per-bot choice):** work-hours-only operating window — solves 3-D Secure confirmations arriving while the owner sleeps.

## Pre-freeze defaults (in force while this file is a placeholder)

- **Shadow mode**: plans and drafts only; zero real transactions; no probes.
- **Approved tools** (the referent of constitution rule 7 until the frozen charter replaces it): the official Privacy.com MCP (`mcp.privacy.com`) *or* the manual prepaid/virtual-card path (no payment tool at all — checkout is a human step, see `RAILS.md`); official Stripe plugin (`mcp.stripe.com`) if selling via Payment Links; AgentMail for agent email; the Telegram reporting tool configured by the humans. Nothing else.
- **Enforcement note**: shadow mode has three layers — the daily-loop step-0 gate (advice), the `spend-gate` hook that blocks payment-pattern commands while this file contains the placeholder banner (speed bump), and NO funded card attached until v1.0 lands here (physics).

## Your bot's charter (filled by the adopt-bot skill, frozen at launch)

- **Bot name / owner:** ____________
- **Avenue (+ runner-up for the day-10 pivot):** ____________
- **Payment rail (from `RAILS.md`):** ____________
- **Runtime (named always-on machine + owner) & pinned model:** ____________
- **Owner's pre-existing subscriptions the bot may use free:** ____________
- **Telegram report chat:** ____________
- **Operating window / timezone:** ____________
- **Kill-switch keyholders (owner + one more):** ____________
- **Disclosure line (exact wording for bios/listings):** ____________
- **Where the money ends up at week 4:** ____________ (fund round 2 / donate / split by prediction-calibration leaderboard — group decides at launch)
