# Forecasts — the bot's calibration ledger (append-only)

Every probe/bet opens one row WHEN IT STARTS: a verifiable claim, a probability, a resolve-by
date. No forecast, no probe. Resolve on or before `resolve_by`: outcome 1 (happened) / 0 (didn't),
Brier = (p − outcome)². Claims must be checkable by a stranger from the evidence link alone.

(The humans' pre-registered predictions about this bot live in `predictions.md` — never mix the two.)

| id | made | claim (verifiable, one sentence) | p | resolve_by | resolved_on | outcome | brier |
|----|------|----------------------------------|---|------------|-------------|---------|-------|
