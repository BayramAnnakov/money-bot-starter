#!/usr/bin/env bash
# sandbox-run.sh — the ONE allow-listed entry point for all untrusted dev work (build/test/install).
#
# Why this exists: bounty repos + competition kits + their transitive deps are untrusted code. Running
# `uv sync` / `make` / `pytest` on the host would execute that code next to the owner's tokens. This
# wrapper runs any command INSIDE an isolated container that has:
#   • a CLEARED environment (no host env is passed → no CLAUDE_CODE_OAUTH_TOKEN / GH_TOKEN reachable),
#   • ONLY the repo's work/ dir mounted (no .env, no ~, no governance files),
#   • generous permissions inside (any tool, any command — a trashed container costs nothing).
# So per-tool approval disappears: inside the box, uv vs cmake vs a cursed `make bootstrap` is no longer
# a security question. The security boundary moved to CONSEQUENCE (money/identity/secrets stay host-side
# and HITL-gated), not to "which tool".
#
# RULE 7 APPLIES TO THIS FILE. The agent must never edit this wrapper or sandbox/Dockerfile — that is how
# a sandbox is escaped. Both are on the deny-list in .claude/settings.json. Changing them is a human act.
#
# Usage:   scripts/sandbox-run.sh [-C <subdir-under-work>] "<command>"
# Example: scripts/sandbox-run.sh -C whest-starterkit "uv sync && uv run python score.py"
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="moneybot-sandbox:latest"
NAME="moneybot-sandbox"

sub=""
if [ "${1:-}" = "-C" ]; then sub="/$2"; shift 2; fi
CMD="${1:-}"
[ -n "$CMD" ] || { echo "sandbox-run: no command given. Usage: sandbox-run [-C <subdir>] \"<command>\"" >&2; exit 2; }

command -v docker >/dev/null 2>&1 || { echo "sandbox-run: docker/orbstack not found — install OrbStack, then scripts/sandbox-build.sh" >&2; exit 127; }
docker info >/dev/null 2>&1 || { echo "sandbox-run: docker daemon not running — start OrbStack/Docker Desktop" >&2; exit 127; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "sandbox-run: image $IMAGE not built — run scripts/sandbox-build.sh" >&2; exit 127; }

mkdir -p "$ROOT/work"

# Start the persistent sandbox if it isn't running. CRITICAL: no --env / --env-file from the host, so the
# container's environment is only the image's. Only work/ is mounted. Runs as the host uid:gid so files
# written into work/ stay editable by the owner on the host. HOME=/tmp gives tool caches a writable home.
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME" >/dev/null 2>&1; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    --memory=6g --memory-swap=6g --cpus=3 --pids-limit=1024 \
    -v "$ROOT/work:/work" \
    -w /work \
    "$IMAGE" tail -f /dev/null >/dev/null || { echo "sandbox-run: failed to start container" >&2; exit 1; }
fi

# Execute inside /work[/subdir] with the container's clean env. bash -c (not -lc) → inherit the container's
# default PATH, which includes /usr/local/bin (uv) and /usr/bin (go/node/gcc/...).
exec docker exec -w "/work${sub}" "$NAME" bash -c "$CMD"
