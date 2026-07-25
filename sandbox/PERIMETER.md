# Sandbox Perimeter Audit (template)

*What the agent can and cannot do WITHOUT asking, once all dev work runs in the sandbox.*
The `sandbox-run` wrapper deletes a whole approval class (per-tool dev approvals), so the honest
question is what capability that trades for. Re-run this audit for your own bot by reading
`scripts/sandbox-run.sh`, `sandbox/Dockerfile`, `scripts/sandbox-build.sh`, and the `sandbox-canary`
result — and re-run `scripts/sandbox-canary.sh` after any Dockerfile change to prove secrets stay unreachable.

## The design intent (and it holds)
The boundary was deliberately moved from *"which tool"* to *"which consequence."* Money, identity, and
secrets stay host-side and HITL-gated; inside the box the agent gets generous permissions because a
trashed container costs nothing. **That contract is intact** — verified below.

## PROTECTED (unreachable from inside the box) ✅
| Asset | Why it's safe |
|---|---|
| Secrets (`CLAUDE_CODE_OAUTH_TOKEN`, `GH_TOKEN`, Stripe key, Telegram token) | `docker run` passes **no** `--env`/`--env-file`; container env = image env only. Canary-verified: zero tokens reachable. |
| `.env`, governance files, git history, ledger | Only `work/` is mounted (`-v $ROOT/work:/work`). Nothing else on the host FS is visible. |
| Host filesystem / `~` / `/Users` | Not mounted. Container sees only `/work` + its own image FS. |
| Host root / privilege escalation | Runs as the **host uid:gid** (`--user`), not root; no `sudo` in the image; the agent can't run `docker` (deny-listed) or edit the wrapper (rule 7). No path to host root. |
| Money / identity / public actions | Never enter the box — they're host-side and HITL-gated by design. |

## GRANTED un-asked (what the capability trade actually bought)
Inside the sandbox the agent may, with **no approval**: run any command/tool, compile and execute
**arbitrary code** (its own or an untrusted bounty repo's build scripts), read/write anything under
`work/`, and — the load-bearing one — **reach the open internet** (full outbound egress; that's how
`uv add` pulls from PyPI).

## RESIDUAL RISKS (ranked)
1. **No resource limits.** `docker run` sets no `--memory` / `--cpus` / `--pids-limit`. A runaway or
   malicious process (fork bomb, memory hog, crypto miner, infinite build) can saturate the OrbStack VM's
   CPU/RAM/PIDs, stalling other sandbox work and the scheduled runs. *Blast radius = the OrbStack Linux VM*
   (not literally the whole Mac), but uncapped within it. **Cheapest real hardening.**
2. **Open egress + untrusted code.** A malicious bounty repo's `make`/`postinstall` script could use the
   owner's IP + compute for outbound abuse (scanning, DoS, botnet, data pull). It is NOT a secrets risk
   (nothing sensitive is reachable), but it is the owner's network identity. Mitigation if untrusted-build
   volume grows: an egress allow-list (PyPI/npm/crates/GitHub only) via a custom docker network.
3. **Persistent container.** `moneybot-sandbox` is long-lived (started once, `docker exec` per command),
   so anything written outside `work/` (installed packages, `/tmp`) persists across runs until a rebuild —
   a compromised dependency survives between days. Mitigation: periodic `sandbox-build.sh` (rebuild is cheap).
4. **No per-command timeout.** A hung `docker exec` blocks the run until the outer `claude` run's own limits
   fire. Minor. Mitigation: wrap the exec in `timeout <N>`.

## RECOMMENDATIONS
- **R1 (do): add resource caps** to the `docker run` line in `sandbox-run.sh` — e.g.
  `--memory=6g --memory-swap=6g --cpus=3 --pids-limit=1024` (tune to the Mac). One line; changing this
  file is a human act (rule 7).
- **R2 (consider, if bounty builds proliferate): egress allow-list** — run the container on a custom
  docker network restricted to package registries + GitHub.
- **R3 (hygiene): rebuild the image weekly** (`sandbox-build.sh`) to clear any persisted state.
- **R4 (optional): per-command `timeout`** inside the wrapper.

## Verdict
The sandbox does what it was built to do: the **consequence boundary is sound** — no secrets, no host FS,
no identity, no host-root reachable. The capability it grants un-asked is *arbitrary sandboxed code with
open internet*, whose worst case is **resource abuse / the owner's IP being used for outbound traffic by
untrusted build code — not a secrets breach.** R1 closes the biggest of those cheaply.
