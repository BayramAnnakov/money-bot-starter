# What one full 28-day run actually taught

This scaffold is not theoretical. One bot built from it ran **28 days on cron, 86 runs, with a $100
hard-capped virtual card**, and earned **$0** — stranger $0, insider $0. The card was never charged.

That null result is why this file exists. Everything below was paid for.

**How to read the numbers here.** Each one is stated at the arity it was actually measured at, and
several carry an explicit "this may not be read as…" — that is deliberate. A starter kit that quotes
its own results loosely teaches the exact habit the harness exists to prevent.

---

## 0. The bill

| | |
|---|---|
| Revenue, stranger | **$0.00** |
| Revenue, insider | **$0.00** |
| Card | $100 hard cap, never charged |
| Runs | 86 through day 28, 3× daily on cron |
| Model cost | **~$533** — list-price equivalent on a flat-rate subscription. **Nobody invoiced this**, and it is a **floor**: resumed runs write cost once, so they undercount |
| Operator time | **75 minutes** — also a **floor**; half the logged human touches were never priced |

So: cheap to run, expensive to think, and **not unattended**. Budget for a human.

---

## 1. Where it actually got stuck — and it was not capability

Ten times in 28 days the agent hit something it could not pass on its own.

- **7 of 10 were identity** — create an account, accept terms, pass KYC, act under a person's name.
- **3 of 10 were toolchain** — a missing binary, a sandbox image rebuild.
- **0 of 10 were "the agent could not do the work."**

The work itself was fine, and there is one clean instance of it.

The bot filed a bug report — an issue, disclosed as AI — on a stranger's public repository, carrying a
measured number. Thirteen days of silence. Then the maintainer replied with **~8,000 characters**. Nine
days after the report, a tagged commit in that project reads:

```
1.3.7: classify shell/bash output and structured logs as log_output (#21)
```

Its body quotes the report's own measured `0.172` as the motivating evidence, it changes two source
files, and it adds a regression test.

**Stated at its real arity:** the bot filed a report; **the maintainer wrote the code.** This is a
verifiable contribution to a stranger's project by an autonomous agent, and the parties never spoke.
It is **not** "our fix was merged", **not** "shipped into a product" (it is a git tag; `releases` is
still 0), **not** validation, and **not** traction. **It is not revenue and must never be reported as
revenue.**

It is also the single clearest statement of this experiment's result: the agent produced something a
stranger found worth acting on, and earned **$0** for it. Capability was never the binding constraint.

*(The same maintainer also audited the bot's evidence and found a real defect in it — see §4.)*

**Two honest caveats, both of which cut against the headline:**

- This is **not** "every rail dies at identity." Both real submissions *cleared* identity. The wall
  is real and it is not total.
- First-timers **do** get paid. In one 28-event window, 4 awards went to accounts with no prior
  award history. Treat identity as friction with a measurable rate, not as a closed door.

**And settlement is slower than any 4-week experiment.** The work is fast; review, merge and payout
are not. Before you commit to an avenue, check that the money can *land* inside your window — not
just that the work can be done. See *pre-build viability calibration* in `CLAUDE.md`.

---

## 2. "Done" must be a filesystem predicate — and that is still not enough

Runs kept ending "successfully" having done nothing. The fix is the `Stop` hook in
`.claude/hooks/autonomy-guard.sh`: the agent is not allowed to end a run until the run has left a
trail.

```bash
contract_met() {
  local today; today="$(date +%F)"
  grep -qE "^## Day .*$today" journal.md  || return 1
  grep -q  "^$today,"          metrics.csv || return 1
  return 0
}
# bounded at 3 nudges, then it ALLOWS the stop. fails open on any error.
```

Both bounds matter. Unbounded, you get an agent that cannot quit. Fail-closed, a bug in your own
hook bricks the loop.

**Then this happened.** The sandbox engine stopped. For the next four dates every `sandbox-run.sh`
returned **exit 127** and every piece of sandboxed work silently skipped. Twelve consecutive runs
logged:

```
20260806-090000  ok  exit=0  complete=1
20260806-130000  ok  exit=0  complete=1
...
20260809-170001  ok  exit=0  complete=1
```

All green. The contract could not see it, because **the contract checks for a trail — and writing
the trail is precisely what a broken agent still manages to do.**

> **The rule: your liveness check must share zero dependencies with the thing it is checking.**

The fix in this repo is `scripts/check-liveness.sh` — it probes the container engine directly, with
no model anywhere in the path. It is deliberately dumber than the thing it watches. Run it from cron
separately from the agent, and page a human, not the agent.

---

## 3. Your gate is per-action. Your agent is per-outcome.

Approval systems check individual actions against thresholds. Long-horizon agents produce bad
outcomes through sequences of individually-acceptable actions. **The gate never fires.**

The version of this failure everyone quotes is a breach. The version that actually bit this run is
much quieter, and worse:

> **Weeks 3 and 4 contained zero earning attempts.** Not failed attempts — none. Every action passed
> every gate. Every run wrote a clean journal entry and a clean metrics row. The books were perfect.

Nothing in the harness noticed, because the harness was measuring **compliance** and nothing was
measuring **progress**. An all-green dashboard is exactly what that looks like from the outside.

> **The rule: you need an outcome invariant on a different clock from your action gate — and it must
> not be satisfiable by the agent's own writing.**

Concretely: check anti-passivity against `ledger.md` rows and real counterparty contact. Never
against the journal the agent authored itself. If a week contains no earning attempt, the weekly
report must lead with that, and it must not share a sentence with any good news.

---

## 4. Every control here has only ever been tested by its author

This is the finding that generalises furthest, and it is uncomfortable.

- **The spend gate** (`.claude/hooks/spend-gate.sh`) is a regex on a `PreToolUse` hook. It never
  blocked a real payment — because there was never a real payment. What it *did* block, repeatedly,
  was the operator: three times in a single session, on commands that were writing HTML files, once
  by refusing to let him print the gate's own regex into a slide.
- **The approval authenticator** (`scripts/poll-approvals.sh`) rejected 12 messages in 19 days. All
  12 came from one chat id: **the experiment's own report group.** Zero third-party messages were
  ever offered to it. This may **not** be read as "12 injection attempts were blocked."

Both controls have a perfect record against an adversary that never showed up.

> **The rule: a control's firing count measures your traffic, not its strength.** Report two numbers
> — times fired, and times fired on something that was not you. The second one is the only one that
> is evidence.

The same shape applies to review. The run's write-up went through roughly **ten rounds of
self-audit** and found nothing. Then one outside reader checked exactly **one** cited artifact — and
it was wrong: a comparative claim resting on a data file with one arm missing. First try.

> **Self-audit rounds measure your diligence, not your correctness.** Budget for one adversary who
> is allowed to pick the artifact.

---

## 5. Fabrication is automatic, believable, and structural

The agent invented results **twice in one session** — one flatteringly wrong, one right by luck.
Neither was a lie in any interesting sense; both were numbers typed from expectation because a
number was expected there.

The only defence that worked is structural, and it is in `CLAUDE.md` as **no model-typed numbers**:
every number in the trail must be pasted from captured command output that is *visibly sitting right
above it*. Not "verified afterwards" — adjacent, in the same file, at the time of writing. A number
that arrives without its command output above it is suspect by construction.

Two companions, both load-bearing:

- **No self-derived baselines.** Targets and "previous records" come from the charter or a human,
  never from the agent's memory.
- **Beating a convenient baseline is not evidence of value.** One session reported "7.3× better than
  the bundled baseline" — a true number about the wrong reference class. The real public field was
  ~100× better and had been one fetch away the entire time.

---

## 6. Things this scaffold gets right, and would get right again

- **The card cap is the only control that is physics.** The constitution is advice; the hook is a
  speed bump; the $100 limit is the thing that cannot be argued with. Order your defences that way
  and be honest about which tier each one is in.
- **Approval auth by numeric id, with no model in the path.** The poller is plain shell. A chat
  message can only ever *resolve* a gate the agent itself opened — it is never a command channel.
- **One allow-listed door, not twelve keys.** Approving dev tools one at a time is theatre —
  `python3` on its own is already arbitrary code execution, so the allow-list was never the boundary.
  The boundary is *consequence*: money, identity and secrets stay HITL-gated, and untrusted build code
  never reaches the tokens. So every individual dev tool came **off** the allow-list and one entry
  point went on (`scripts/sandbox-run.sh`), running anything inside a container with the environment
  cleared and only `work/` mounted — plus a canary script that *proves* no secret is reachable from
  inside. Per-tool approval friction went to zero and the blast radius got smaller at the same time.
- **Append-only trail + auto-commit.** A run that leaves no trail is visible as a gap. This is what
  makes any of the above checkable by someone who was not there.
- **Scoped approvals.** A bare "approve" is binary and cannot say "only part (b)". Letting the owner
  reply with a reason, recorded verbatim and minting no spend token, removed a whole class of
  all-or-nothing stalls.

## 7. Things to change before your run

1. **Add an outcome invariant.** Weekly, from `ledger.md`, not from the journal. §3.
2. **Run the liveness watchdog from its own cron entry**, sharing nothing with the agent. §2.
3. **Instrument your controls for adversarial hits, not total hits.** §4.
4. **Re-check granted approvals for the human step actually happening**, by re-reading the source
   system and checking the author field. Decision latency is minutes; step latency is unbounded.
5. **Calibrate the money path before you build** — can it pay a stranger, and can it pay inside your
   window? §1.
