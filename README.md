# Money Bot Starter

Scaffold for the AI Natives autonomous money-making experiment (kicked off 2026-07-03).

One repo = one agent = one P&L. The repo IS the observability layer: constitution, ledger, and decision log are all markdown, all auditable by the group.

**Clone model:** there is ONE flagship instance of this repo (the group's bot, group's card, group's ledger). Members who want a personal bot FORK it, run their own card/budget/chat, and keep their own P&L — personal instances never post to the flagship's chat or write to its ledger.

## Layout

```
CLAUDE.md        — the agent's constitution (mission, budget, guardrails, HITL gates)
AGENTS.md        — pointer for Codex/other agents → read CLAUDE.md
charter.md       — the group-approved experiment charter v1.0 (placeholder until frozen)
state.md         — bounded working memory: snapshot, open bets, next actions, HITL queue (agent rewrites daily)
ledger.md        — every cent in and out; the single source of truth for P&L
decisions.md     — decision log: what the agent chose, why, expected vs actual, EVIDENCE
predictions.md   — members' probabilistic predictions (with confidence %), locked at kickoff, scored at retro
retro.md         — the humans' weekly retro: reconciliation, intervention count, surprises (bot-manager owns it)
.env.example     — expected secrets (copy to .env; .env is gitignored)
prompts/
  kickoff.md     — first-run prompt (shadow mode: plan only, no spending)
  daily-loop.md  — the recurring "hustle" prompt
.claude/skills/
  daily-report/  — posts the one-line P&L to Telegram
```

## How to run (Claude Code; Codex works via AGENTS.md)

Order matters — the session picks the avenue BEFORE the agent plans:

1. At the kickoff session: pick the avenue, agree the charter, paste it into `charter.md` (charter.md is the single source of truth; every decided value elsewhere is a copy of it)
2. Fill in the blanks in `CLAUDE.md`, `ledger.md`, and the Roles block below FROM the charter
3. Copy `.env.example` → `.env` and fill in (never commit `.env`)
4. First run — shadow mode: `claude "$(cat prompts/kickoff.md)"` — the agent produces a plan + budget forecast, NO real transactions
5. Group/owner reviews the plan — the first human-approval moment of the experiment
6. Daily loop thereafter: `claude "$(cat prompts/daily-loop.md)"` — from the RUNTIME machine (below), wired as a cron/scheduled agent

## Roles & runtime (fill in at kickoff — bots with no home die by Tuesday)

- **Runtime:** ____________ (named always-on machine or cloud worker + its owner). Example wiring: `crontab -e` → `0 9 * * * cd /path/to/money-bot && claude -p "$(cat prompts/daily-loop.md)" >> logs/daily.log 2>&1`
- **API/compute costs paid by:** ____________ (reported in the weekly net line — compute can quietly exceed the card budget; see the $47k-loop case)
- **Card/wallet owner (the named human carrying KYC + tax responsibility):** ____________
- **Week-1 bot-manager:** ____________ — rotates weekly. The job, concretely: run the weekly reconciliation + retro (`retro.md` — no code required), score prediction trends, adjudicate disputed stranger/insider tags, ship one improvement PR to the constitution (a dev can pair on the PR if the manager doesn't use git)
- **Repo admin (merges constitution PRs; amendments to the frozen charter need a meeting decision, not just a PR):** ____________
- **Daily human touch (anyone, <5 min):** clear `state.md` pending-approvals and blockers — a blocked agent is an idle agent, and idle agents drift

Non-developers participate fully: make a prediction, own the weekly reconciliation/retro, audit the ledger — none of it needs a terminal.

## Rules that are not optional

- The card limit is the real guardrail. Prompt-level limits are advice; card-level limits are physics.
- Cards are merchant-locked, one per merchant; the agent never handles a raw card number in the open.
- Every transaction gets a `ledger.md` row BEFORE the money moves (agent writes intent, then result).
- Every claimed success needs an evidence link. Weekly, a HUMAN reconciles the ledger against the card + processor dashboards (agents misread their own dashboards — see AI Village).
- Human does: KYC, account creation, payment method attachment, physical steps, cold-outreach approvals, and everything per charter gates.
- If the agent can't explain a spend in one sentence in `decisions.md`, it doesn't spend.

## Kill switch

> Note: this section and `.env.example` assume the proposed Privacy.com + Stripe stack. If the charter freeze picks a different rail (e.g. crypto wallet), update BOTH before go-live — a kill switch pointing at the wrong provider is not a kill switch.

- Pause the card: **Privacy.com dashboard** (fastest, always works — verify you can do this BEFORE go-live; the CLI `privacy cards pause <token>` only if installed and authed)
- Revoke the Stripe restricted key: Stripe dashboard → API keys
- Stop the loop: kill the cron/scheduled session on the runtime machine
- Keyholders and auto-stop conditions: see `charter.md`

## Shadow mode — what actually enforces it

Two layers: (1) `daily-loop.md` step 0 halts spending while `charter.md` is a placeholder — that's prompt-level, i.e. advice; (2) the real teeth: **no funded card or payment method is attached until the charter is frozen**. Don't wire a live card at the kickoff session.
