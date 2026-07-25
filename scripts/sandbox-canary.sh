#!/usr/bin/env bash
# sandbox-canary.sh — PROVE the sandbox has zero secrets reachable (Fable's #1 rule: verify empirically,
# not by inspection). Run this after every image rebuild and before trusting the box. Exits non-zero if
# ANY secret is reachable from inside.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/scripts/sandbox-run.sh"
fail=0

echo "=== CANARY: is anything sensitive reachable from inside the sandbox? ==="

echo "--- 1. tokens in the container env? (must be empty) ---"
out="$("$RUN" 'env | grep -iE "token|secret|key|password|_api" || true')"
if [ -n "$out" ]; then echo "❌ LEAK — env exposes:"; echo "$out"; fail=1; else echo "✅ no secret-shaped env vars"; fi

echo "--- 2. can it read the host .env / governance files? (must NOT) ---"
out="$("$RUN" 'for f in /work/../.env ../.env /.env /work/../../.env; do [ -r "$f" ] && echo "READABLE: $f"; done; cat /work/../.env 2>/dev/null | head -c 40 || true')"
if [ -n "$out" ]; then echo "❌ LEAK — host files reachable:"; echo "$out"; fail=1; else echo "✅ host .env not reachable"; fi

echo "--- 3. what home / mounts does it see? (should be /tmp home, only /work mounted) ---"
"$RUN" 'echo "HOME=$HOME"; echo "whoami uid=$(id -u):$(id -g)"; echo "--- / contents ---"; ls -a / | tr "\n" " "; echo; echo "--- can it see host home? ---"; ls /Users 2>/dev/null && echo "❌ /Users VISIBLE" || echo "✅ no /Users"'

echo "--- 4. toolchain present? (uv/python/node/go/gcc) ---"
"$RUN" 'for t in uv python3 node go gcc make cmake; do printf "%s=%s  " "$t" "$(command -v $t || echo MISSING)"; done; echo'

echo
if [ "$fail" -eq 0 ]; then echo "✅ CANARY PASSED — no secrets reachable inside the sandbox."; else echo "❌ CANARY FAILED — DO NOT trust the sandbox until fixed."; fi
exit $fail
