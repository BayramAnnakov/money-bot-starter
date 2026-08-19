# Money Bot Starter

Scaffold for an autonomous money-making agent: constitution, ledger-first guardrails, HITL gates,
and an append-only audit trail. Built for the AI Natives league (kicked off 2026-07-03).

> ### It has been run. It earned $0.
>
> One bot built from this scaffold ran **28 days on cron, 86 runs, on a $100 hard-capped card** and
> earned **nothing** — stranger $0, insider $0. The card was never charged.
>
> **[LESSONS.md](LESSONS.md) is the write-up of that null result**, and it is the most useful file
> here: where the run actually got stuck (7 of its 10 blocking gates were *identity*, none were
> capability), how the completion contract stayed green through four days of a dead sandbox, and why
> every guardrail in this repo is still untested by anything other than its author.
>
> Read it before you plan your run. It will not tell you this scaffold makes money.

One repo = one agent = one P&L. The repo IS the observability layer: constitution, ledger, and decision log are all markdown, all auditable by the group.

**League model (decided at kickoff):** every participant runs their OWN bot from this template — own idea, own $100, own card, own Telegram chat, own P&L. Use GitHub's *Use this template* (or fork), then run the adopt-bot skill below. The upstream repo doubles as the league roster: PR your row into `REGISTRY.md`. Bots never share a ledger or a report chat.

## Layout

```
CLAUDE.md        — the agent's constitution (mission, budget, guardrails, HITL gates)
LESSONS.md       — what a completed 28-day run taught: the null result, and the harness bugs it exposed
AGENTS.md        — pointer for Codex/other agents → read CLAUDE.md
charter.md       — kickoff decisions + your bot's charter (placeholder until YOU freeze it)
RAILS.md         — payment-rails picker: what actually worked at the kickoff, by geography
playbooks.md     — the four avenues: time-to-first-dollar, KYC, ToS landmines, first probe
REGISTRY.md      — league roster + the comparable weekly report format
state.md         — bounded working memory: snapshot, open bets, next actions, HITL queue (agent rewrites daily)
ledger.md        — every cent in and out; the single source of truth for P&L
decisions.md     — decision log: what the agent chose, why, expected vs actual, EVIDENCE
journal.md       — narrative trail: one bounded entry per run (beliefs, actions, surprises, updates)
forecasts.md     — the bot's calibration ledger: verifiable claim + p + resolve-by, Brier-scored
predictions.md   — members' probabilistic predictions (with confidence %), locked at kickoff, scored at retro
retro.md         — the owner's weekly retro: reconciliation, intervention count, surprises
interventions.md — every human touch, priced in owner-minutes (revenue per human-hour = the sustainability number)
metrics.csv      — one machine-readable row per day; league-frozen schema (see OBSERVABILITY.md)
runs.csv         — run telemetry written by the wrapper: status, duration, api cost, complete?
OBSERVABILITY.md — the audit map: four layers, single-writer rule, retention, liveness, week-4 recipe
approvals/       — one-time spend-approval tokens + consumption log (see Enforcement)
evidence/        — screenshots backing ledger/decision claims (REDACT card numbers + PII first)
logs/            — raw run transcripts + errors (gitignored; retained locally — they're the audit ground truth)
scripts/
  run-daily.sh      — canonical cron entrypoint: preflight, timeout, completion-contract check, auto-resume, heartbeat, crash ping, auto-commit
  preflight.sh      — fail-fast env check before each run (auth token, tools, git, sandbox engine): HARD-fail skips the run instead of burning it; answers "is it actually running?"
  check-liveness.sh — independent watchdog (no claude dependency): alerts if no complete run when there should be one; also probes the sandbox engine when the sandbox module is enabled
  poll-approvals.sh — owner-only approval channel: numeric-id auth, deterministic (no LLM); group + other DMs ignored; also flushes the outbox
  send-outbox.sh    — delivery-checked flush of the agent's queued Telegram messages
  outbox-add.sh     — the agent's only way to queue a message (it never calls the Telegram API directly)
  watch.sh          — local tail of run state: what the loop is doing right now
  sandbox-run.sh    — OPTIONAL: the one allow-listed entry point for all untrusted dev work (build/test/install) inside an isolated container
  sandbox-build.sh  — OPTIONAL: (re)build the sandbox image
  sandbox-canary.sh — OPTIONAL: prove the sandbox has zero host secrets reachable (run after any Dockerfile change)
sandbox/            — OPTIONAL (see "Sandboxed dev work" below)
  Dockerfile        — the isolated build/test image (Python+uv, Node, Go, C/C++)
  PERIMETER.md      — audit of what the agent CAN and CANNOT do without asking, once dev work runs in the box
.env.example     — expected secrets + liveness config (copy to .env; .env is gitignored)
prompts/
  kickoff.md     — first-run prompt (shadow mode: plan only, no spending)
  daily-loop.md  — the recurring "hustle" prompt (the daily run: trail + report)
  work-session.md — the mid-day working prompt (execution only; writes no journal/metrics row)
.claude/
  skills/adopt-bot/         — the setup interview: "adopt this bot" → fills every blank
  skills/daily-report/      — posts the one-line P&L to Telegram
  skills/request-approval/  — pushes HITL approval requests to the owner (Telegram ping + state.md row)
  skills/ask-advisor/       — an independent red-team POV on the day's top fork (a stance, not necessarily a different model; advice, not command)
  skills/convene-council/   — a multi-perspective panel for weekly review + mandatory pre-pivot
  hooks/spend-gate.sh       — PreToolUse hook that blocks payment-pattern commands without approval
  hooks/autonomy-guard.sh   — Stop hook: won't let a run quit before its trail/completion-contract is met
```

## Your first 24 hours (prep week runbook)

1. **Template/fork this repo** (private is fine — your ledger will contain real numbers).
2. **Open Claude Code in it and say `adopt this bot`.** The adopt-bot skill interviews you (avenue, geography → rail, chat, subscriptions, window, keyholders) and fills every `<FILL>` and blank across the repo. ~15 minutes, no code.
3. **Do the human-only setup** it hands you at the end, per `RAILS.md`: payment rail + KYC, agent email, GitHub account, Telegram chat + bot. These are yours by design — see *What the model will refuse* below.
4. **Shadow kickoff:** `claude "$(cat prompts/kickoff.md)"` — the agent produces a plan + budget forecast, NO real transactions.
5. **Review the plan** (the first human-approval moment) and PR your row to the upstream `REGISTRY.md`.
6. **Launch day:** freeze your charter — delete the PLACEHOLDER banner block AND the pre-freeze defaults section in `charter.md` (your filled charter now owns the toolset); that deletion IS the freeze — then attach the funded card, run ONE < $5 end-to-end test transaction to prove the spend rail, and wire the schedule (three lines; ask your agent to set them up — a one-sentence request in Claude Code):
   ```
   0 9 * * *        /path/to/money-bot/scripts/run-daily.sh        # the daily loop (wrapper, never bare `claude`)
   0 12,15,18 * * * /path/to/money-bot/scripts/check-liveness.sh   # independent watchdog, a few times in your window
   */3 * * * *      /path/to/money-bot/scripts/poll-approvals.sh   # owner-only DM approvals (ignores group + all other DMs)
   @reboot          caffeinate -s                                   # macOS: keep the machine awake through the window
   ```
   The wrapper captures the full transcript, records cost + completion to `runs.csv`, auto-resumes a mid-task stop, pings you on failure, and auto-commits — so every run leaves a trace even when the agent inside it fails. Then create a free **dead-man's-switch** (e.g. healthchecks.io), put its ping URL in `.env` as `HEALTHCHECK_URL`, and it will alert you even if the machine was off all day and *nothing* ran. See `OBSERVABILITY.md §Liveness`.

## Roles (league mode: you wear most hats — name them anyway)

- **Owner = card/KYC/tax holder = bot-manager.** You run the weekly reconciliation + retro (`retro.md`, no code required), score prediction trends, and bring the numbers to the meetup.
- **Runtime:** a named always-on machine (bots with no home die by Tuesday). Compute costs: your existing LLM subscription; report anything beyond it in the weekly net line.
- **Daily human touch (< 5 min, non-negotiable):** clear `state.md` pending-approvals and blockers — a blocked agent is an idle agent, and idle agents drift. You won't need to poll: the request-approval skill pings you on Telegram the moment a gate fires (`TELEGRAM_OWNER_CHAT_ID`); spend approvals are granted with `touch approvals/APPROVE`, human steps by doing them and marking the row done. Steering budget: ~1 intervention/day, logged (week 1 exempt).
- **The weekly meetup is the league's cross-bot review:** everyone brings the same 5-line report (format in `REGISTRY.md`), disputes over stranger/insider tags get adjudicated there.

Non-developers participate fully: adopt-bot needs no code, the retro needs no code, predictions and ledger audits need no code.

## What the model will refuse (by design — plan around it)

Observed live at the kickoff session: Claude refused account signup steps outright (*"my operating rules prohibit me from completing account creation"*), refused entering emailed verification codes, and the constitution independently bars it from CAPTCHAs and raw card numbers. Don't fight this and don't route around it with a more compliant model — these refusal points map exactly onto the charter's human gates. Budget your own time for: signups on human platforms, KYC, verification codes/magic links, CAPTCHAs, 3-D Secure confirmations, and any manual-card checkout.

## Enforcement — three tiers (know which one you're trusting)

1. **Prompts** (constitution, daily-loop gates) = advice. Necessary, not sufficient.
2. **The spend-gate hook** (`.claude/hooks/spend-gate.sh`, wired via `.claude/settings.json`) = a speed bump with teeth: any Bash command matching payment patterns is blocked unless a one-time token exists. The agent writes the request to `state.md`; you grant exactly one execution with `touch approvals/APPROVE` (consumed + logged to `approvals/log.md` on use). While the charter still contains its placeholder banner, the hook blocks payment-pattern commands unconditionally — shadow mode with teeth. Limits: it sees Bash, not browser clicks — which is fine, because browser checkouts are a HUMAN step per constitution rule 6. **Claude Code only:** other runners (Codex etc., via AGENTS.md) don't read `.claude/settings.json` and silently lose this tier — they run on tier 1 + tier 3 alone, so keep the card limit tighter there.
3. **The card limit** = physics. The only guardrail that holds when everything above fails. Never attach a card whose limit you wouldn't burn.

## Optional: sandboxed dev work (needs Docker/OrbStack)

Skip this whole section if your avenue never runs untrusted code (a digital-product store, a research-report bot). Turn it ON if your avenue means building/testing code you didn't write — **OSS bounties, competition kits, their transitive deps.** Running `uv sync` / `make` / `pytest` on such a repo executes that code next to your tokens; the sandbox moves the security boundary from *"which tool"* (a per-command approval treadmill) to *"which consequence"* (money/identity/secrets stay host-side and HITL-gated, while inside the box the agent gets generous permissions because a trashed container costs nothing). A Jul-2026 league bot found this was the single biggest enabler of autonomous dev work — it deleted a whole approval class.

**Enable it:**
1. Install Docker Desktop or OrbStack.
2. Build the image: `scripts/sandbox-build.sh` (reads `sandbox/Dockerfile`).
3. Set `SANDBOX_ENABLED=1` in `.env`.
4. Set the engine to start on login so a reboot doesn't leave the bot with no sandbox — OrbStack: `orb config set app.start_at_login true`; Docker Desktop: Settings → "Start Docker Desktop when you sign in".
5. **Tighten the allow-list** in `.claude/settings.json`: remove the host `Bash(python3/node/npm/pnpm/pytest)` allows so untrusted code *only* ever runs inside the box, via `scripts/sandbox-run.sh -C <subdir> "<cmd>"`. (The sandbox deny-list — no editing `sandbox-run.sh`/`Dockerfile`, no bare `docker` — already ships and is harmless if unused.)

**What ships with it:** `sandbox-run.sh` (the single allow-listed entry point: cleared env, only `work/` mounted, host uid, resource caps), `sandbox-build.sh`, `sandbox-canary.sh` (proves zero host secrets are reachable — run it after any Dockerfile change), `sandbox/Dockerfile`, and `sandbox/PERIMETER.md` (the standing audit of what the box grants un-asked — read it, and re-run it for your own image). The watchdog (`check-liveness.sh`) gains an engine-reachability probe **only when `SANDBOX_ENABLED=1`**: a run can "complete" while the engine is down and sandbox work silently skips, so it pings you (deduped) if the engine is unreachable in-window.

## Rules that are not optional

- The card limit is the real guardrail. Prompt-level limits are advice; card-level limits are physics.
- Cards are merchant-locked, one per merchant; the agent never handles a raw card number in the open.
- Every transaction gets a `ledger.md` row BEFORE the money moves (agent writes intent, then result).
- Every claimed success needs an evidence link. Weekly, a HUMAN reconciles the ledger against the card + processor dashboards (agents misread their own dashboards — see AI Village).
- Human does: KYC, human-platform account creation, payment method attachment, physical steps, cold-outreach approvals, and everything per charter gates.
- The report chat is write-only for the agent: it streams, it never reads. Owner talks to the bot through the repo, not the chat.
- If the agent can't explain a spend in one sentence in `decisions.md`, it doesn't spend.

## Kill switch

> Match this to YOUR rail from `RAILS.md` before go-live — a kill switch pointing at the wrong provider is not a kill switch.

- **Prepaid/neobank rail (the league's mainstream path):** freeze the card in the bank app (Revolut: Cards → Freeze). Verify you can do it BEFORE go-live.
- **Privacy.com:** pause the card in the dashboard (fastest, always works); the CLI only if installed and authed.
- **Stripe (if selling):** revoke the restricted key: dashboard → API keys.
- Stop the loop: kill the cron/scheduled session on the runtime machine.
- Keyholders and auto-stop conditions: your `charter.md`.

## Shadow mode — what actually enforces it

Three layers: (1) `daily-loop.md` step 0 halts spending while `charter.md` contains its placeholder banner — prompt-level, i.e. advice; (2) the spend-gate hook hard-blocks payment-pattern commands for the same condition; (3) the real teeth: **no funded card or payment method is attached until you freeze the charter**. Don't wire a live card during prep week.
