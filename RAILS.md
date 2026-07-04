# Payment Rails — pick yours in 5 minutes

Field-tested live at the kickoff session (2026-07-03). This is the part of the experiment that ate
50 minutes of a room full of engineers — don't re-discover it. Pick by your situation, not by
what's coolest.

## The decision tree

| Your situation | Rail | Agent's role | Notes |
|---|---|---|---|
| US resident (SSN, US address) | **Privacy.com** virtual cards | Agent can mint merchant-locked capped cards via the official MCP | KYC took minutes at the session. The MCP costs $5/mo — if one static card is enough, skip the MCP and just set the card's hard limit in the dashboard |
| Everyone else (EU/UK/GE/NZ/...) | **Neobank virtual/disposable card** (Revolut, Wise) with a hard limit | NONE at checkout — the agent prepares the purchase, YOU pay (constitution rule 6) | The league's mainstream path. Revolut has no agent API for personal accounts — that's fine, the card limit is the guardrail, not the API |
| No bank you want anywhere near this | **Prepaid Visa gift card** (Tremendous, or retail/Amazon) | Same — human checkout | Zero KYC exposure; the limit is literally the card's face value |
| Closed-loop avenue (Polymarket) | **Crypto wallet** funded with exactly the budget | Agent can operate inside the loop | Spend and earn in ONE system — no card at all. Mind taxes and your jurisdiction's access rules |
| Telegram bot / mini-app avenue | **Telegram Stars** | Fully agent-operable | No KYC, no card for receiving; payouts have a ~21-day hold, so "verified revenue" = Stars received, cash lands after week 4 |

## What we actually verified on the call (so you don't have to)

- **Privacy.com: works** — KYC passed, card created (Bayram, US). US-residents-only is hard-enforced.
- **AgentMail: works end-to-end** — agent self-registered, received inbound, used the address to sign up on a real service. Two gotchas: outbound lands in **spam** and gets a *"Sent via AgentMail"* footer appended. Workaround (Mike): auto-forward to Gmail, strip the footer, send from there.
- **AgentCard: flaky, geography-hostile.** Magic-link loops instead of codes, dashboard reachable only via agent-generated links that sometimes never arrive, an **SSN wall for non-US users** (it asked a German resident for a US SSN), "too many signups" rate-limits. One member did get a card issued fully autonomously (Georgian docs!), so it CAN work — but budget zero reliance on it.
- **Claude refuses signup steps.** Live quote from the session: *"my operating rules prohibit me from completing account creation."* It also declined entering emailed verification codes. This maps exactly onto the charter's human gates — do these steps yourself (README §What the model will refuse).
- **3-D Secure is unsolved for autonomy.** A purchase at 3am triggers a bank confirmation on YOUR phone while you sleep. Mitigations: operating window (agent transacts only in your waking hours — charter option), or a rail without 3DS (prepaid gift cards, Stars, crypto).

## Rules that apply to every rail

1. The limit lives at the **card/wallet level**, not in the prompt. Prompt budgets are advice; card limits are physics.
2. One card per merchant where the rail allows it; the agent NEVER sees or types a raw card number.
3. Test the **kill switch before go-live**: can you freeze this card in under a minute from your phone?
4. Revenue lands on the **owner's account** (KYC reality) — it never tops the card back up; the ledger tracks both sides.
5. Whatever you pick, write it into `charter.md` — the kill-switch section and the approved-tools list must match your rail.
