# Agent Entry Point

Read `CLAUDE.md` — it is the constitution for this agent regardless of which coding agent runs it (Claude Code, Codex, or other). All rules there apply verbatim.

Heads-up for non-Claude-Code runners: the spend-gate enforcement hook lives in `.claude/settings.json` and only Claude Code executes it. Under any other runner you operate WITHOUT tier-2 enforcement (see README §Enforcement) — the constitution and the card limit are all that stand between you and a mistake, so the owner should set the card limit accordingly.
