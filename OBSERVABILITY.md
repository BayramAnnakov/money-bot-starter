# Observability — how this experiment stays auditable

Four layers, each with one consumer and one question it answers. **Single-writer rule:** every
file has exactly one writer (agent, wrapper, or owner) — if you're editing someone else's file, stop.

| Layer | Files | Writer | Consumer & question |
|---|---|---|---|
| Working memory (rewritten daily) | `state.md` | agent | tomorrow's run: "where was I?" |
| Append-only record | `ledger.md` · `decisions.md` · `journal.md` · `forecasts.md` · `interventions.md` · `metrics.csv` · `approvals/log.md` · `evidence/` | agent (owner prices `interventions.md` minutes) | weekly audit + week-5 write-up: "what actually happened, and was it worth it?" |
| Raw traces (local-only) | `logs/transcripts/*.jsonl` · `logs/daily.err` · `runs.csv` | wrapper (`scripts/run-daily.sh`) | dispute resolution + cost analysis: "what did the agent REALLY do, and what did the run cost?" |
| Public heartbeat | Telegram: daily one-liner, ⏸️/✅ approval transparency posts, wrapper crash pings | agent (skills); wrapper on failure | the league, in real time: "is it alive, is it earning, is it stuck?" |

## The rules that make it hold

1. **A run that leaves no trace didn't happen.** Every daily run appends one `journal.md` entry,
   one `metrics.csv` row, and any due `forecasts.md` resolutions. The wrapper commits after every
   run regardless — a commit with no journal/metrics diff is itself a finding.
2. **Git is the tamper-evidence.** Append-only files are never rewritten; the per-run commit makes
   any edit visible in history. (`state.md` is exempt — it is DESIGNED to be rewritten.)
3. **Raw transcripts are retained, not published.** The wrapper captures the full stream-json
   transcript of every run under `logs/transcripts/` (gitignored: huge, and may contain tool output
   you don't want public). Keep them for the experiment + 30 days — they're the ground truth when a
   journal/ledger claim is disputed. The AI Village audit that surfaced fabricated-success cases was
   only possible because traces existed.
4. **Run telemetry ≠ ledger.** `runs.csv` records per-run `api_cost_usd`, turns, duration (from the
   transcript's result envelope). League rules exempt the owner's LLM subscription from the $100 —
   but the week-5 write-up MUST report it: "would this be profitable at API prices?" is the real
   sustainability question, and hiding the token subsidy is the exact dishonesty this group formed to avoid.
5. **Human time is a cost.** Every resolved HITL item and every owner steer lands in
   `interventions.md` with owner-reported minutes. A bot that "earned" $40 on six hours of human
   babysitting did not earn $40 — the write-up divides revenue by owner-minutes.
6. **Forecasts are the calibration ledger.** Every probe opens a numbered forecast (verifiable
   claim, probability, resolve-by). Resolutions get outcome ∈ {0,1} and Brier = (p − outcome)².
   The week-4 calibration curve comes straight out of this table. (`predictions.md` is different —
   that's the HUMANS' pre-registered predictions about the bot.)
7. **Schemas are frozen.** `metrics.csv` and `runs.csv` columns are league-standard: never add,
   rename, or reorder columns — week-4 cross-bot analysis is a blind concat of every repo's CSVs.
   Avenue-specific meaning goes into the charter's funnel definitions, not into new columns.
8. **MEASURED vs INFERRED.** Everything agent-written is agent-reported until the weekly human
   reconciliation (`retro.md`); a metrics row is not "verified" by existing. Reconciled weeks are
   marked in `retro.md`.

## metrics.csv schema (agent appends exactly one row per run day)

```
date,day_n,shadow,balance_usd,card_spend_today,external_svc_spend_today,revenue_stranger_cum,revenue_insider_cum,funnel_a,funnel_b,funnel_c,probes_active,forecasts_open,approvals_pending,note
```

`shadow` = 1 while charter.md contains PLACEHOLDER, else 0. `funnel_a/b/c` = your avenue's three
funnel numbers, defined ONCE in `charter.md` at freeze (e.g. visits, checkout clicks, paid orders).
`note` ≤ 80 chars. Unknown value = empty cell, never a guess.

## runs.csv schema (wrapper appends one row per run)

```
run_id,date,status,exit_code,duration_ms,num_turns,api_cost_usd,attempts,subtype,complete,transcript
```

`status` ∈ `ok | timeout | error | incomplete`. `complete` = 1 iff the day's trail exists
(journal entry + metrics row) — the **source of truth**: a run is DONE when it leaves a trace,
regardless of exit code or `subtype`. `attempts` counts the auto-resume retries.

## Liveness — how a stopped bot gets noticed (three layers)

Autonomous agents die silently — API errors, turn/context limits, a closed laptop — and silence
reads as passivity. Three watchers, each dumber and more reliable than the thing it watches, plus one
machine-checkable definition of done.

**The completion contract (stale-by-design vs stopped-mid-task):** a run is *done* iff it wrote
today's `journal.md` entry AND today's `metrics.csv` row. Full trail + clean stop → done, no alert.
Missing trail, or `subtype:"error_max_turns"`, or a non-zero exit → stopped mid-task → recover, then
alert. No run at all → cron/machine failure → alert.

1. **The wrapper** (`scripts/run-daily.sh`) — in-run safety: a single-flight lock, a per-attempt
   `timeout` (a hang can't run forever), reads the stream-json result envelope, checks the completion
   contract, **auto-resumes once** (the retry re-reads `state.md` and finishes), writes a `.last-alive`
   heartbeat + pings the external switch on a complete run (and `/fail` on an incomplete one), Telegram-
   alerts the owner on failure, and commits every run.
2. **The watchdog** (`scripts/check-liveness.sh`) — independent, **no `claude` dependency**, cron'd a
   few times inside the operating window: if no complete run exists for today and the last good run is
   stale (`STALE_AFTER_HOURS`), it pings the owner (and optionally triggers one catch-up run). Catches
   what the wrapper can't — the cron that never fired while the machine was on. **If the OPTIONAL sandbox
   module is enabled (`SANDBOX_ENABLED=1`)** it also probes the sandbox engine (`docker info`): a run can
   "complete" its trail while Docker/OrbStack is DOWN — every `scripts/sandbox-run.sh` then exits 127 and
   sandbox dev work silently skips, a failure the completion contract can't see — so it fires a distinct
   deduped alert (and, with `AUTO_RECOVER=1`, an `orb start` self-heal). Primary fix for the reboot case
   is the engine's own "start on login" setting; the watchdog is the belt-and-braces for a mid-day engine
   crash or a reboot with no login session.
3. **The external dead-man's-switch** (`HEALTHCHECK_URL`, e.g. healthchecks.io) — the only thing that
   catches "the machine was off all day, nothing ran at all": if the wrapper's alive-ping doesn't
   arrive on schedule, the external service escalates to the owner. One-time human setup; pair with
   `caffeinate` to keep the machine awake through the operating window.

## Week-4 analysis recipe (~15 minutes, one bot or the whole league)

1. Concat `metrics.csv` across repos → daily P&L and funnel curves per bot.
2. Concat `runs.csv` → total API cost; recompute every bot's net at API prices.
3. `forecasts.md` → mean Brier + calibration plot (bucket by p).
4. `interventions.md` → total owner-minutes; revenue per human-hour.
5. `journal.md` + `decisions.md` → the narrative: quote real entries, count `[EXTERNAL]`
   injection attempts, count kill-criteria honored vs rationalized away.
