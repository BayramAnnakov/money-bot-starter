# Money Bot Starter

Scaffold for the AI Natives autonomous money-making experiment (kicked off 2026-07-03).

One repo = one agent = one P&L. The repo IS the observability layer: constitution, ledger, and decision log are all markdown, all auditable by the group.

## Layout

```
CLAUDE.md        — the agent's constitution (mission, budget, guardrails, HITL gates)
AGENTS.md        — pointer for Codex/other agents → read CLAUDE.md
charter.md       — the group-approved experiment charter v1.0 (placeholder until frozen)
ledger.md        — every cent in and out; the single source of truth for P&L
decisions.md     — decision log: what the agent chose, why, expected vs actual, EVIDENCE
predictions.md   — members' falsifiable predictions, locked at kickoff, scored at retro
.env.example     — expected secrets (copy to .env; .env is gitignored)
prompts/
  kickoff.md     — first-run prompt (shadow mode: plan only, no spending)
  daily-loop.md  — the recurring "hustle" prompt
.claude/skills/
  daily-report/  — posts the one-line P&L to Telegram
```

## How to run (Claude Code; Codex works via AGENTS.md)

1. Fill in the blanks in `CLAUDE.md` and paste the frozen charter into `charter.md`
2. Copy `.env.example` → `.env` and fill in (never commit `.env`)
3. First run — shadow mode: `claude "$(cat prompts/kickoff.md)"` — the agent produces a plan + budget forecast, NO real transactions
4. Group/owner reviews the plan (this is HITL gate #1)
5. Daily loop thereafter: `claude "$(cat prompts/daily-loop.md)"` — from the RUNTIME machine (below), or wire a cron/scheduled agent

## Where this runs (fill in at kickoff — bots with no home die by Tuesday)

- **Runtime:** ____________ (named always-on machine or cloud worker + its owner)
- **API/compute costs paid by:** ____________ (reported in the weekly net line)
- **Week-1 bot-manager:** ____________ (rotates weekly: owns the weekly report + one improvement PR)

## Rules that are not optional

- The card limit is the real guardrail. Prompt-level limits are advice; card-level limits are physics.
- Cards are merchant-locked, one per merchant; the agent never handles a raw card number in the open.
- Every transaction gets a `ledger.md` row BEFORE the money moves (agent writes intent, then result).
- Every claimed success needs an evidence link. Weekly, a HUMAN reconciles the ledger against the card + processor dashboards (agents misread their own dashboards — see AI Village).
- Human does: KYC, account creation, payment method attachment, physical steps, cold-outreach approvals, and everything per charter gates.
- If the agent can't explain a spend in one sentence in `decisions.md`, it doesn't spend.

## Kill switch

- Pause the card: Privacy.com dashboard (or `privacy cards pause <token>`)
- Revoke the Stripe restricted key: Stripe dashboard → API keys
- Stop the loop: kill the cron/scheduled session on the runtime machine
- Keyholders and auto-stop conditions: see `charter.md`
