# Finance — Zoo

<!--
Roadmap 6.9 ("Make the day-to-day sing"). Two **economic levers** that add a
*decision*, not just another readout — the genre's "interesting choices":

  - Loan: borrow a lump sum now, repay it (with interest) in equal daily
    instalments over a fixed term. Bridges a rough opening week — the exact
    "a bad open shouldn't be a permanent hole" problem the reputation rework
    (2026-06-11) already fights for, now with a cash tool to match.
  - Sponsorship: take a corporate sponsor's signing bonus plus a daily payout
    for a fixed term, in exchange for an immediate reputation cost (guests
    grumble about the branding). Trades prestige for cash flow.

Both are one-at-a-time, run from the gate's Park Admin panel, and settle each
day through the normal Ledger. Game-side tuning (the engine doesn't read it),
compiled by src/finance_config.gd; the lever logic + save round-trip live in
src/bootstrap.gd.

Accounting note: the loan principal and its repayments are *financing*, not
operating earnings, so their Ledger sources are deliberately left
uncategorized (they land in Accounting's OTHER bucket and never inflate the
"revenue" figure a contract/milestone reads). Sponsor money is genuine earned
income and is categorized as revenue.
-->

## Loan

principal     = 4000
interest_rate = 0.25
term_days     = 20

## Sponsorship

signing_bonus   = 1500
daily_income    = 80
term_days       = 25
reputation_cost = 3
