#!/usr/bin/env bash
# sandbox-build.sh — (re)build the moneybot-sandbox image and drop any stale running container so the
# next scripts/sandbox-run.sh picks up the new image. Human action (rule 7) — not the agent's to run.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v docker >/dev/null 2>&1 || { echo "docker/orbstack not found — install OrbStack first" >&2; exit 127; }
docker info >/dev/null 2>&1 || { echo "docker daemon not running — start OrbStack/Docker Desktop" >&2; exit 127; }

echo "Building moneybot-sandbox:latest …"
docker build -t moneybot-sandbox:latest "$ROOT/sandbox"
docker rm -f moneybot-sandbox >/dev/null 2>&1 || true
echo "✅ built. Next sandbox-run starts a fresh container from it."
