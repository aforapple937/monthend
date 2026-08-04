# §11 Stored Processes

One section per stored process. **Confirmed** holds established facts;
**Open questions** holds anything unconfirmed, uncertain or possibly wrong.
Nothing here restates what the code says — read the `CODE_*.txt` for that.

Index and file map: `FRS9_Work_Reference.md`. Shared machinery — cycle
sequence, EGL mapping, account string, posting mechanics, TB exports, HO's
files: `MER_00_Cycle_and_Posting.md`. Table grain, keys and widths:
`SAS_Tables_Knowledge.md`. SAS conventions and traps: the sas-writing skill.

---

## 11.1 Pre-Check TB — `precheck_tb.sas` — `CODE_precheck_tb.txt`

**Confirmed**

- The check works because only this team should ever post to the ECL and EIR
  GLs. Any movement before the month's journals go in was posted by somebody
  else, so movement is the exception rather than the measure.
- `PTD_NET_ENTERED` is the tested figure, not `PTD_NET_ACCOUNTED`. ACCOUNTED
  carries EGL's automatic FX revaluation — the system restating what is already
  there, not somebody posting — so testing it would break every month on any
  foreign-currency account. A genuine foreign-currency posting still lands in
  ENTERED.
- The two `*_PNL_WRITEOFF` GLs are out of scope because Remedial and Consumer
  Credit post the write-off charge into them during the month. On a gross
  100,000 write-off with 30,000 ECL held, they post Dr ECL P&L 100,000 / Cr
  Loans 100,000 and this team posts Dr ECL BS 30,000 / Cr ECL P&L 30,000,
  leaving the 70,000 unprovided portion. The BS leg **is** in scope.
- January tests the swept GLs on balance rather than movement — `YTD_NET_ENTERED`
  nil. Stronger: it proves the sweep completed *and* that nobody else posted,
  where movement proves only the second. It works because the transfer
  (`MER_00` §7) is posted before this check runs.
- Two different sweeps land those GLs at nil. The BS charge, writeback and
  write-off GLs and their `UWI_*` twins are emptied into the opening GLs by the
  January transfer; the P&L GLs close to retained earnings at year end, as every
  P&L account does.
- `EIR_BS` and `FVOCI_BS` keep the ordinary movement test in January, since no
  sweep touches them.
- Three GLs are not tested at all in January. `ECL_OPENING` and `UWI_OPENING`
  because the sweep posts *into* them — movement is expected, and nil balance
  would be wrong since they hold the prior December closing. `FVOCI_OCI` because
  it is not known whether it closes out at year end.

**Open questions**

- The opening GLs are not checked in January. After the sweep they should equal
  the prior December closing ECL, which is `RCY_ECL_OPENING_BAL` on the current
  year's RDL — the same figure from two directions, and the check that would
  prove the sweep moved the *right amount*. Not built.
- Whether `FVOCI_OCI` closes out at year end. If the reserve does sweep it
  belongs on the balance test; if not, on the movement test.

---

## 11.2 Balance Recon — `balance_recon.sas` + `map_setup.sas` (run once) — `CODE_balance_recon.txt`, `CODE_map_setup.txt`

**Confirmed**

- The TB side uses `YTD_NET_ACCOUNTED`, not `ENTERED` as the pre-check does.
  ACCOUNTED is the SGD-translated figure and `LEDGER_BALANCE_AMT` on the product
  files is SGD, so both sides are SGD and same-signed and the difference is a
  straight subtraction with no FX step.

**Open questions**

- None recorded.

---

## 11.3 Currency Change Check — `ccy_change.sas` — `CODE_ccy_change.txt`

**Confirmed**

- The HO engine stores the opening ECL without a currency and takes the currency
  from the monthly files Singapore sends, so when an account's currency changes
  mid-year the engine reads the opening figure as if it had always been in the
  new currency. Opening SGD 100,000 against a closing JPY 17m posts a charge of
  17m − 100k.
- The fix is a patch to HO, not a local adjustment. Each month the changed
  accounts go to HO carrying account number, new currency and the converted
  opening ECL.
- Keyed on `AC_CODE` alone, not account-within-file. An account can move between
  product files during the month — OD to LN, say — and keying on the file as
  well would show that as one closure plus one new account rather than a
  currency change.

**Open questions**

- The converted opening ECL is not built. The script produces the account and
  the new currency only.
- Where the opening (31 Dec prior year) ECL sits — `RDL_MSTR_LIST` or
  `RDL_AC_DTL` back from HO, or somewhere local.
- Which rate converts it — 31 Dec closing, current month-end, or a rate HO
  specifies.

---

## 11.4 Input File Validation (in build) — `val_ln.sas` + `valid_values_setup.sas` (run once) — `CODE_val_ln.txt`, `CODE_valid_values_setup.txt`

**Confirmed**

- The aim is high-level detection of a broken IT batch, not field-by-field
  correctness. That is why checks are driven by `SASFILES.VALID_VALUES` rather
  than hardcoded — extending scope is a data edit, not a code change.
- Built for `LN_DTL` first, table-parameterised so the other four product files
  can follow.
- Check B tests the current month only: it is validating the file about to go to
  HO, so a value that existed last month and has since disappeared is not a
  problem with that file.
- `CREDIT_CLASSIFICATION` takes the worst class where an account carries more
  than one flag — `IMP` over `SMA` over `WLS` over `NML/EWS`.
- The derived columns are exempt from A and B: they are built from columns
  already checked.
- A column with a single allowed value is skipped by C, because a share
  comparison is meaningless when only one value is permitted.
- C's prior-month population excludes accounts closed during that month, so its
  percentages will not tie to raw file counts. That is the intended like-for-like
  basis, not a defect.

**Open questions**

- Which of the 29 unchecked columns come into scope next, and the rules for the
  high-cardinality ones.
- Whether `LGD` and `ACCT_UTILISATION` are 0–1 or 0–100.
- Whether one month is enough to freeze the allowed-value lists.
- `LAST_PYM_DTE` was 15% blank in June; the in-month rule assumes a payment every
  month, so a loan last paid in May would report as a breach.
- `CREDIT_CLS_TYP_CODE` showed no `S02` or `S04` in June — unknown whether those
  are valid values that simply had no rows.
- `BASEL_LGD_CLS` runs `P 1` to `P 7` then `P 9` to `P 13`, with no `P 8` — note
  the embedded space.
- `RPYM_TYP` carries `666`, `777` and `820` on under 0.3% between them. `666` and
  `777` look like sentinels.
- The 5-point threshold in C is uncalibrated, which is why every row prints.
- C cannot see account-level movement: a column can hold a steady share while
  accounts flip both ways underneath it.
- Rolling the mechanism out to the other four product files.
- The final stored-process name and its slot in the sequence.

---

## 11.5 SORA Rate Patch — `sora_patch.sas` — `CODE_sora_patch.txt`

**Confirmed**

- The SORA rates carried on fixed-then-floating accounts go stale, so each month
  the current values are substituted and two patch files go to IT to apply at
  source.
- Only the floating tiers on `RT_DTL` are patched, identified by `BASE_RT`
  matching **that account's own** SORA rate rather than any rate seen across the
  population. Matching on the population would patch a 90-pegged account's tier
  with the 91 rate if the two ever coincided.

**Open questions**

- The business reason for the patch has never been recorded — only the mechanics.
- "Latest" means furthest scheduled, not in force at month end: `RT_EFF_DTE` can
  be after the reporting date. Adding `datepart(RT_EFF_DTE) <= &rpt_dt` to the
  interface read would switch to the in-force reading.
- A fixed-period tier whose rate happens to equal the account's own SORA rate
  would be caught and patched. Nothing in `BASE_RT` distinguishes them; the only
  comfort is that SORA rates carry odd decimals.
- Whether to pre-format the dates as text for the recipient.

---

## 11.6 SORA Patch Verification — `sora_verify.sas` — `CODE_sora_verify.txt`

**Confirmed**

- None recorded.

**Open questions**

- The 200-row exception cap has no full-population table behind it. The count is
  in the title so truncation is visible, but a bad month would print only the
  first 200.

---

## 11.7 EGL Reversal Check — `egl_reversal.sas` — `CODE_egl_reversal.txt`

**Confirmed**

- The comparison nets to account string + currency, because that is the grain the
  ledger posts at. A net of zero is proof the reversal undid the posting.
- Pairing line to line would not be possible in any case. One account can appear
  on several lines in a file and nothing on a line identifies which is which; the
  only field that varies is the description, and it carries its own month —
  `0626 ECL CHARGED` against `0526 ECL CHARGED`.

**Open questions**

- None recorded.

---

## 11.8 EGL Posting Check — `posting_check.sas` — `CODE_posting_check.txt`

**Confirmed**

- The GL comes from the EGL Mapping. The `GL_ID_*` columns exist on RDL and are
  deliberately not used.
- The posting is year-to-date: `FY` columns, not `FTM`. FVOCI is not posted.

**Open questions**

- `MOD_GAIN_LOSS` columns exist on RDL and are not covered. If HO posts
  modification gain/loss it would show as `Not expected`. Unconfirmed whether it
  is posted at all.
- An account whose key finds no GL goes to a printed exception rather than to the
  expected side, so if HO posted it, it also appears as `Not expected` — one
  cause, two symptoms.
- A GL that should be ECL-related but is absent from the mapping is invisible on
  both sides. Only fixable in the mapping.

---

## 11.9 Post-Posting TB Recon — `post_recon.sas` — `CODE_post_recon.txt`

**Confirmed**

- This is the check that proves the **ledger** is right, where §11.8 only proves
  HO's file matched the engine. It catches a rejected line, a partial load, or
  someone posting over the top.
- **The P&L cannot be reconciled.** EGL translates a P&L posting to SGD when it
  books it and never revalues it; the balance sheet is revalued to closing rate
  every month. The reversal of last month's posting comes back at a different
  rate from the original, and that FX residue is absorbed on the BS by
  revaluation but accumulates on the P&L in SGD with nothing in RDL to match it.
  Hence `YTD_NET_ENTERED` against `RCY_` amounts — both in original currency,
  both immune to revaluation.
- The opening and FVOCI signs are the least certain of the ten components. A
  wrong sign shows as a difference of exactly twice the amount.
- FVOCI has a fixed account string, so every FVOCI account in an entity and
  currency lands on one string. A difference there identifies entity and currency
  only; `POSTRECONDTL` is the only way to see which accounts fed it.
- Opening and EIR are summarised rather than itemised because opening balances
  always differ at account level: when an account changes RC or product, RDL
  rebuilds the 8-segment string while the TB still carries the opening under the
  old one — two offsetting differences that cancel only once RC and product are
  dropped.
- The TB filter is on GL only, so a posting to the right GL with a wrong product
  code still surfaces. A blank `COMPONENT` means the GL is absent from the
  mapping, which should not happen.

**Open questions**

- The EIR line carries a standing difference on MSL. The AEL Adjustment (§11.11)
  posts to `1207001` with nothing in RDL to match, and those entries telescope,
  so the accumulated contribution is the current pool BS balance. Expect `252`
  MSL to differ by that month's `TOTAL_BS` and `128` MBS to be zero — predicted,
  not yet verified against a month's output. The fix, not built, is to add the
  pool's current BS to the expected side for `252` only.

---

## 11.10 ECL Flux — `ecl_flux.sas` — `CODE_ecl_flux.txt`

**Confirmed**

- Only borrowers with a non-zero current-month `ECL_PNL_FTM` are reported. That
  filter does real work: RDL accumulates through the year, so by mid-year it
  holds every account opened since January, most of them dormant.
- Charge **plus** writeback, not minus: the LCY writeback column is already
  signed negative while its RCY twin is positive. Swapping an LCY column for its
  RCY equivalent without changing the sign would silently double the figure.
- Rating and stage come from the account with the largest EAD — current EAD for
  the current columns, prior EAD for the prior ones. If all of a borrower's
  accounts sit at EAD 0 there is nothing to discriminate on and the first row
  sorted wins.
- The name is current-state while the sub-segment is as at the reporting date, so
  a borrower renamed since month-end prints its new name against its old segment.

**Open questions**

- The `CFS-IND` literal in the printed summary has never been verified against
  `PARTY_MSTR` (`Open_Items.md` item 10). A wrong spelling matches nothing and
  prints `0.00`, which reads exactly like a genuine nil.
- Rows where `LEGAL_ENTITY` is neither `001` nor `003` fall outside both the MBS
  and MSL lines, so the summary does not necessarily tie to the whole table.
  Whether such rows occur has not been checked.

---

## 11.11 EIR AEL Adjustment — `eir_ael_adj.sas` — `CODE_eir_ael_adj.txt`

Related: `Accounting_Positions.md` §5.1, `Open_Items.md` item 4.

**Confirmed**

- The HO engine applies a changed AEL to **new accounts only**; existing accounts
  stay on the AEL in force at their booking date. On a historical AEL change the
  team took the view that the change should apply to the existing book as well —
  the IFRS 9 B5.4.6 catch-up. The engine could not do that, so the impact was
  quantified outside it in a one-off simulation and the per-account amounts have
  been carried on a schedule ever since. This process is the monthly servicing of
  that schedule.
- **Closed pool.** Nothing is ever added; only prior-month `Active` rows roll
  forward, so it can only shrink. When the last account closes the schedule goes
  to nil.
- **No amortisation.** Each amount is carried forward unchanged and is not
  unwound against the engine's own EIR amortisation.
- **Released in full at closure**, so the month's P&L charge is exactly the
  amount attaching to accounts that closed.
- MSL only, which is why the posting file carries no entity field.

**Open questions**

- The cliff-at-closure treatment rather than a gradual unwind is a timing
  simplification. Recorded as a deliberate choice, but not confirmed as an
  explicit decision.

---

## 11.12 FVOCI Loan MTM — `fvoci_mtm.sas` — `CODE_fvoci_mtm.txt`

**Confirmed**

- HO does not compute the FVOCI mark. Singapore computes it here, posts it, and
  sends a patch file so `RDL_AC_DTL` carries the same figure.
- The journal is whole-balance — reverse the entire prior mark, post the entire
  current one. Not the YTD-movement basis ECL uses, which is the wrong assumption
  to bring to this journal.
- Accounts whose mark came out missing go into the patch file with blank amounts.
  Dropping them silently would leave last month's fair value in place on RDL.
  They are listed in a printed exception instead.
- The summary's prior column and `PREV_MTM_GAINLOSS` do not agree, by design. The
  summary totals every account in prior-month FVOCI RDL; the detail column only
  reaches accounts still in this month's active population. The reversal has to
  back out everything posted last month, including accounts since closed.
- The RCY total on the summary adds figures held in different currencies, so it
  is a control total for tying back, not a meaningful amount.

**Open questions**

- Nothing matches on tenor: WAIR is struck on rate type and currency only, so a
  seven-year loan is discounted at a rate drawn from all tenors.
- `VALUE_DTE` is being used as a proxy for origination. If it resets on rollover
  or re-drawdown, rolled facilities re-enter the benchmark at their repriced rate.
- The benchmark is filtered to Active before the window is applied, so a loan
  written inside the window and repaid before month end contributes nothing.
  Whether that biases the rate, and in which direction, is untested.
- Why the three carve-outs mark to nil is not recorded. `RESIDUAL_MTH <= 12`,
  `DEFAULT_FLG = 'Y'` and `LT_6_MONTHS = 'Y'` are held at carrying value; the
  reasoning behind each was never written down.
- An unparseable `AA_FAC_REF` leaves `MOB` missing, and missing sorts below 6, so
  the account is silently held at carrying value rather than marked. Whether that
  is intended is unconfirmed.
- Two different notions of vintage, from two different fields: the benchmark keys
  on `VALUE_DTE`, the `MOB < 6` carve-out on `AA_FAC_REF`.
- `RESIDUAL_MTH` uses `abs(yrdif(...))`, so a matured account gets a positive
  residual — preserved, not endorsed.
- Entity is not carried in the GL file and the aggregation is by currency across
  both entities. Safe only while FVOCI loans are single-entity.
- Whether the run should stop outright rather than send a patch file with blank
  amounts in it.

---

## 11.13 EIR Future Repricing Adjustment — `eir_fut_repricing.sas` — `CODE_eir_fut_repricing.txt`, `CODE_load_prior_futrepricing.txt` (one-off)

**Confirmed**

- Business units sometimes tag an account as repriced at a future date. Until the
  repricing takes effect, the position taken is that the EIR movement arising
  from the tag should not be recognised. The engine has no view on this, so the
  correction is made locally and holds the EIR balance sheet at its pre-tagging
  level for as long as the account stays future-tagged.
- **The RDL patch is what makes it a freeze rather than a lag.** Telescoping a
  movement alone would hold the balance sheet at last month's balance, rolling
  forward each month. After this process runs, IT patches `LCY_EIR_ADJ_AMT` on
  the current month's RDL rows to the prior figure, so next month reads the
  patched value as its prior balance and the baseline carries forward unchanged:

  | | May | Jun | Jul |
  |---|---|---|---|
  | `cur` — engine, unpatched | 130 | 145 | 160 |
  | `prv` — RDL, patched | 100 | 100 | 100 |
  | `EIR_DIFF` | 30 | 45 | 60 |
  | **Reported EIR BS** | **100** | **100** | **100** |

- **The process is only correct if it runs before the patch.** Rerun afterwards
  and `cur` reads the patched figure, the movement collapses to nil, no entries
  are produced, and the schedule is overwritten empty — leaving next month
  nothing to reverse, silently.
- `RDL_MSTR_LIST` is deliberately **not** patched. Patch the engine-native layer
  and the engine would carry the hold forward itself, the diff would collapse to
  nil, and the adjustment would stop working after one month.
- One column is enough in the patch file: IT's loader recomputes the LCY movement
  columns off the patched `LCY_EIR_ADJ_AMT`. The RCY side is **not** derived —
  see §11.15.
- The reversal is written first and the current entry second, matching what the
  uploader expects — the opposite order to §11.11.
- MSL only, and unlike §11.11 the population is not closed, so an MBS housing
  loan with a future repricing tag could drift in. The script stops if anything
  non-MSL appears.
- The schedule is held at account level so the reversal re-aggregates the
  **stored** `BIZ_UNIT_CODE` and `FINANCING_CODE` rather than re-deriving them
  from a prior-month `LN_DTL` that may since have been restated.

**Open questions**

- Whether `BAL_AFT_EIR_ADJ` is also auto-derived by IT's loader. Nothing in the
  pack reads it, but it sits beside the patched column at the same format.
- `MSTR_LIST.EIR_PREVIOUS` disagrees with patched `AC_DTL` for these accounts, so
  if the EIR-leg cross-check against §11.7 is ever built, this population has to
  be carved out of it.

---

## 11.14 Overlay Watchlist — `overlay_watchlist.sas` — `CODE_overlay_watchlist.txt`

**Confirmed**

- Same engine as §11.10, different question. `ECL Flux` asks *who moved* and
  takes every borrower with a non-zero month P&L. This asks *what happened to
  these specific borrowers*, whether they moved or not — a nil movement on a
  watched name is itself the answer. It therefore keeps a borrower present in
  only one of the two months, where the flux filter would drop them.
- The CIF list arrives on a prompt rather than from a table because the overlay
  population is a judgement, not a derivable filter.
- Nothing is persisted — the printed report is the whole deliverable. Answering a
  question about a watched borrower later in the month means rerunning, which
  works as long as RDL for both months is still in place.
- The ECL shown is the **engine** ECL. The overlay itself is not on RDL, so this
  shows where the model has got to, not the total provision.
- The prompt is named `CIF_LIST`, not `CIF_NO`: a prompt sharing a name with a
  column on the tables being read fails quietly.
- `NODUPKEY` on the name lookup should delete nothing. It is the standing check
  that `V_T_CIF_MSTR` really is keyed on `CIF_NO` alone.
- A requested CIF with no RDL row in either month is a finding, not an absence. A
  typo and a genuinely absent borrower look identical, so the requested list is
  rebuilt as a dataset and the gaps printed separately.

**Open questions**

- Whether the stored process and program were renamed on the server when
  `Overlay Monitoring` became `Overlay Watchlist`, or only the titles inside the
  code.
- For the sector MOA (`Accounting_Positions.md` §5.2), a `STAGE_MOVE` of `Yes` on
  a Stage 1 → Stage 2 line is the model catching up with what was already
  provided for — a release candidate. Judging whether the overlay remains
  adequate in total needs the overlay schedule alongside, which this process does
  not read.

---

## 11.15 ECL Manual Override — `ecl_override.sas` — `CODE_ecl_override.txt`

**Confirmed**

- Forces ECL to the full ledger balance for every in-scope account under a named
  list of customers — a manual full provision the engine cannot produce, since it
  is a credit judgement rather than a model output.
- Two ordering constraints. `EGL Posting Check` must run **before** IT applies the
  patch, or every overridden account shows a difference equal to the top-up and
  reads as an HO discrepancy. And this process must read **unpatched** RDL, since
  the amounts are the gap between the target and the engine's own figures.
- Unlike §11.13 the patch is **not load-bearing**: each month recomputes against
  a fresh engine figure, so a patch that never gets applied leaves that month's
  RDL disagreeing with the ledger — a reporting break, not a mechanism break.
- **The amount posted is not the engine's own gap.** The year's movement is
  derived from `CLOSING = OPENING + CHARGE − WRITEBACK − WRITEOFF`, so
  `NET_REQ_FY = target − opening + write-off`, and what gets posted is the
  difference per component against what HO already posted. Worked example —
  opening 180, engine closing 20, ledger balance 120: required movement is a
  release of 60, HO posted a writeback of 160, so the difference is a writeback
  of −100. Entry: Cr ECL writeback (BS) 100 / Dr ECL writeback (P&L) 100. Booking
  a charge of 100 instead would reach the same closing provision but inflate both
  gross P&L lines by 100.
- No January carve-out is needed: `OPENING_BAL` in January *is* December's
  closing, so the difference is already the January movement.
- Conversion to account currency happens **before** the subtraction, not after.
  Converting the gap would leave the provision a cent or two off the balance, and
  the point is that it equals the balance exactly.
- Non-SGD accounts are printed because `T_MTH_CURCY_EXCHG` carries variant
  currency codes alongside the standard ones — `CNO`/`CNH` beside `CNY`,
  `INO`/`INH` beside `INR` — and a join on `CURCY_CODE` treats a variant as an
  unrelated currency.
- The two patch files are asymmetric because IT's loader is. The LCY file carries
  closing only and the loader derives the movement columns; the RCY movement
  columns are **not** derived, so they are carried explicitly.
- The FTM columns are included deliberately: `ECL Flux` reads the FTM pair, so
  without them the override would not appear in the flux report at all.
- **The reversal is manual.** The amount posted is year-to-date, so next month's
  run recomputes the whole position and last month's entry must be reversed in
  full, not topped up. Nothing in the script enforces this.
- There is deliberately no already-patched guard: a card portfolio in default is
  legitimately provisioned at the full ledger balance by the engine, so "no gap
  anywhere" is a normal state, not evidence of a rerun.

**Open questions**

- `ENTITY_CODE` is carried in the entries table and the GL upload template has no
  column for it. A CIF can hold accounts in both entities, unlike the
  single-entity pools of §11.11 and §11.13, so the file must be split by entity
  before upload.
- Whether IT's LCY derivation reaches FTM and splits charge/writeback the same
  way. Worth confirming after the first load.
- Both journal legs use the same account-string segments, differing only in the
  GL. That matches §11.8 but is inferred for the P&L side.
- `CHK_TOPUP` and `CHK_IDENT` are columns, not guards. If either is ever non-zero
  the files should not be sent, which argues for making them abort.
- FY is built from the net-movement rule while FTM uses the same rule against
  prior closing, and nothing cross-checks the two. They will disagree for an
  account where the engine booked both a charge and a release in one month.

---

## 11.16 RDL Patch Verification — `rdl_patch_verify.sas` — `CODE_rdl_patch_verify.txt`

Built August 2026.

**Confirmed**

- One check for every patch file. Three processes send them — §11.12, §11.13 and
  §11.15, the last sending two.
- **File-driven by design.** No column list exists anywhere in the script and no
  file name is recognised, so a new patch file needs no change here — drop it in
  the folder and it is verified.
- Keyed on `UNIQUE_ID_NO` alone. **Consequence: a stale file is invisible.** Last
  month's patch file left in the folder will be verified against this month's RDL
  and mostly report `Differs`, with nothing saying why. `My SAS Files\patch` has
  to be cleared each month.
- `Differs` cannot distinguish "IT did not apply it" from "IT applied it wrong".
  Unlike §11.6, there is no pre-patch snapshot — the file states only the target.
  The exception listing prints both values so the distinction can be made by eye.

**Open questions**

- Not yet run against a live patch cycle.
- A check comparing each file's own `PROC_DTE` against the prompt was left out on
  the instruction to ignore that column. It remains the obvious hardening if a
  stale file ever gets through.
