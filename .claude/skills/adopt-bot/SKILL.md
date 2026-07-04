---
name: adopt-bot
description: Set up your own money bot from this template — interviews the owner, fills every blank in the constitution/charter/ledger, and hands back the human-only checklist. Use when the user says "adopt this bot", "set up my bot", "customize the starter", or clones the template fresh.
---

# Adopt This Bot

You are onboarding a NEW OWNER of a forked/templated money-bot repo. Interview them, personalize
every file, and end with the checklist of steps only a human can do. The whole flow is conversational —
assume the owner may be a non-developer. Target: under 15 minutes.

## Ground rules for this skill

- **Never ask for secret values** (tokens, keys, card numbers) in chat. You tell the owner WHICH
  values go into `.env`; they fill it themselves.
- **Never create accounts or attach payment methods** — those are the owner's steps, listed at the end.
- **Never delete the PLACEHOLDER banner in `charter.md`.** Deleting it is the owner's freeze act on
  launch day; your job is to make the charter ready-to-freeze, not frozen.
- If the repo has already been adopted (no `<FILL>` markers left), say so and offer to re-run
  specific sections instead of overwriting.

## Step 1 — Interview (batch related questions, don't fire 12 at once)

Collect, in 3-4 conversational rounds:

1. **Identity:** bot name; owner name/handle; repo URL if pushed.
2. **Avenue:** walk them through the four options in `playbooks.md` (one line each); get the pick
   AND the runner-up (day-10 pivot target). If they're stuck, ask what they already do well —
   avenue 1 (productized service) is the default for anyone with a marketable skill.
3. **Money:** geography/residency → recommend a rail from the `RAILS.md` decision tree and confirm;
   budget (league default $100 — deviating means leaving league standings); spend gate (default $20);
   who is the second kill-switch keyholder besides the owner.
4. **Operations:** Telegram report chat (do they have a bot + chat yet? if not, point to the checklist);
   runtime machine (always-on box/cloud + cron, or "manual daily run" as honest fallback);
   pinned model; operating window + timezone (recommend work-hours if their rail has 3DS);
   pre-existing subscriptions the bot may use free (LLM plan, 11Labs, etc.);
   exact disclosure line (offer: "I'm an AI agent — an experiment by the AI Natives group").

## Step 2 — Personalize the repo

Apply the answers everywhere; keep formatting intact:

- `charter.md`: fill the "Your bot's charter" section (leave "where the money ends up" blank if
  undecided — it's a launch-day group decision). Do NOT touch the banner.
- `CLAUDE.md`: replace every `<FILL>` (avenue, budget, gate, probe math = budget/10).
- `ledger.md`: starting balance/limit, timezone; start date stays open until launch (note "launch: 2026-07-10").
- `state.md`: initialize the snapshot header with the bot name and Day 0.
- `.env`: DON'T write it. Copy nothing; instead list which `.env.example` keys their rail actually
  needs (e.g. manual-card rail needs no Stripe key unless they sell via Payment Links).
- `.claude/settings.json` + hook: confirm `spend-gate.sh` is executable (`chmod +x`); no edits needed.
- Draft their `REGISTRY.md` row (for the PR to the upstream repo) and show it.

## Step 3 — Verify

- Grep for leftover `<FILL` markers and `____` blanks in CLAUDE.md/ledger.md — report any that
  remain and why (only acceptable: launch-day values).
- Confirm the PLACEHOLDER banner is still in `charter.md` (shadow mode intact).
- Echo a 6-line summary of the personalized setup for the owner to sanity-check.

## Step 4 — Hand off the human-only checklist

Print it explicitly — these are things YOU must not and cannot do (see README §What the model will refuse):

1. Payment rail setup per `RAILS.md` (KYC, card creation, hard limit set) — but attach NO funded card until launch day.
2. Agent email (AgentMail or a fresh workspace account) — expect spam-folder + footer gotchas (RAILS.md).
3. GitHub account for the bot, if the avenue needs one.
4. Telegram: create the report bot + group chat, put the token + BOTH chat ids (report chat, your DM for approval pings) into `.env`.
5. PR the registry row to the upstream repo.
6. Run the shadow kickoff: `claude "$(cat prompts/kickoff.md)"` and review the plan.
7. On launch day (2026-07-10): delete the charter banner (the freeze), attach the card, one <$5
   end-to-end test transaction, wire the cron.
