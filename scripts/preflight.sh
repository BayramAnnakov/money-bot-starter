#!/usr/bin/env bash
# preflight.sh — fail-fast environment check run BEFORE each claude session (called by run-daily.sh).
#
# WHY: this week the loop was broken THREE times by the environment, not the model — Day-1 cron/keychain
# auth death, a power outage, and a reboot that left the sandbox engine Stopped. Each half-ran or burned a
# session on a broken env. This checks the things that silently break and fails fast, so a completed run
# is a *preflighted* run — which is also the answer to the owner's recurring "is it actually running?".
#
# EXIT: 0 = go (green, or a degraded-but-usable env that was alerted). 1 = HARD abort — run-daily skips the
# claude invocation (and pings the dead-man's-switch /fail) so nothing is silently eaten.
# Also runnable by hand: `scripts/preflight.sh; echo $?` prints PASS / SOFT-WARN / HARD-FAIL to stderr.
set -u
export PATH="$HOME/.local/bin:$HOME/.orbstack/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
mkdir -p logs
[ -f .env ] && set -a && . ./.env && set +a

hard=""; soft=""
add_hard(){ hard="${hard}"$'\n'"• $1"; }
add_soft(){ soft="${soft}"$'\n'"• $1"; }

# --- HARD: a run cannot do useful work OR leave a trail without these (universal blockers) ---
command -v claude >/dev/null 2>&1 || add_hard "claude not on PATH — the loop cannot run"
{ [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; } \
  || add_hard "no headless auth token in .env — fix: run 'claude setup-token', add CLAUDE_CODE_OAUTH_TOKEN=… to .env"
command -v git >/dev/null 2>&1 || add_hard "git not on PATH"
command -v jq  >/dev/null 2>&1 || add_hard "jq not on PATH — telemetry + the approval poller break"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || add_hard "not a git work tree (repo broken)"
[ -w . ] || add_hard "repo dir not writable"

# --- SOFT: the run can still do non-affected work; alert but proceed (do not skip a whole run) ---
if [ "${SANDBOX_ENABLED:-0}" = "1" ]; then
  if ! command -v docker >/dev/null 2>&1; then add_soft "SANDBOX_ENABLED=1 but docker CLI missing"
  elif ! docker info >/dev/null 2>&1; then    add_soft "SANDBOX_ENABLED=1 but Docker/OrbStack engine down — sandbox-run will exit 127"; fi
fi
if command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-}" ]; then
  # Probe an authed endpoint, but RETRY — `gh` hits the network to validate, so a single transient blip
  # must not cry wolf (observed 2026-07-25: a false "gh auth failing" alert while the token was valid).
  # `rate_limit` is a real auth check (401 on a bad token) that doesn't consume quota. Warn only if ALL fail.
  gh_ok=0
  for _ in 1 2 3; do gh api rate_limit >/dev/null 2>&1 && { gh_ok=1; break; }; sleep 2; done
  [ "$gh_ok" = 1 ] || add_soft "gh auth failing after 3 tries (GH_TOKEN expired/revoked?) — bounty scouting via gh will fail"
fi

alert(){ # alert <text> — owner DM (no secrets); best-effort
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || return 0
  local chat="${TELEGRAM_OWNER_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"; [ -n "$chat" ] || return 0
  curl -s -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$chat" --data-urlencode text="$1" >/dev/null 2>&1 || true
}

if [ -n "$hard" ]; then
  echo "$(date -u +%FT%TZ) preflight: HARD-FAIL —${hard//$'\n'/ }${soft//$'\n'/ }" >> logs/daily.err
  alert "🤖🛑 Preflight FAILED $(date +%H:%M) — skipping this run so a broken env doesn't burn a session:${hard}${soft}"
  printf 'PREFLIGHT: HARD-FAIL%s\n' "$hard" >&2
  exit 1
fi
if [ -n "$soft" ]; then
  echo "$(date -u +%FT%TZ) preflight: SOFT-WARN (proceeding) —${soft//$'\n'/ }" >> logs/daily.err
  alert "🤖⚠️ Preflight — run proceeding, but a capability is degraded:${soft}"
  printf 'PREFLIGHT: SOFT-WARN%s\n' "$soft" >&2
  exit 0
fi
echo "PREFLIGHT: PASS" >&2
exit 0
