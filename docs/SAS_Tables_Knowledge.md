# SAS Tables Knowledge

The FRS9/DWH tables — grains, keys and conventions. Consuming processes are the
`MER_*` files, mapped in `FRS9_Work_Reference.md`.

Status markers: **[C]** confirmed, **[I]** inferred, **[O]** open.

## The `.txt` companion files

| File | Contents |
|---|---|
| `LIBRARY_TABLENAME.txt` | `PROC CONTENTS` of one table |
| `LIBRARY_TABLENAME__COLUMNNAME.txt` | the derivation of one column, rebuilt in SAS |

The `__COLUMN.txt` files are a **lineage library for reference, not a production
workstream** — IT's Informatica derivations restated in SAS, so "where does this
field come from" can be answered without asking IT. Search them before answering
any lineage question. **[C]**

`FRS9_LN_DTL_pending_derivations.txt` lists the columns not yet rebuilt.
`LBFRS9_T_MTH_RSME_CMPLX_PRD_WRK_TBL.txt` is a work table feeding the
`LN_DTL.ALLOCATED_COST` derivation, not a table in the monthly flow. **[C]**

**Two defects run through the library** — fixed in `V_SEGMENT_NAME` only, so
expect them elsewhere. **[C]**

1. **`datepart(PROC_DTE)` month filters** — correct but slow; fix with the
   bounded-literal rule in §2.
2. **Hash lookup variables typed numeric by accident.** A variable appearing
   only in a `RETAIN` or `CALL MISSING` — never in a `SET` — is created numeric,
   so `definedone()` fails with `Type mismatch for data variable` against a
   character lookup column. Fix: `if 0 then set <lookup dataset>;` after the
   `RETAIN` and before the main `SET`.

---

## 1. Data model

Monthly IFRS 9 / MFRS 9 Expected Credit Loss (ECL) reporting.

    DWH tables → INPUT tables → ECL engine → MSTR_LIST → RDL

`LBDWH` tables feed the product input tables in `LBFRS9`, which feed the ECL
engine. The engine writes the engine-native `RDL_MSTR_LIST`, from which the
business-named `RDL_AC_DTL` is derived. Both RDL tables sit in `LBFRS9` too, as
output rather than input.

### Tables

`PROC_DTE` is the month-end date; snapshots are retained month-on-month.

| Table | Grain (unique key) | One row = |
|---|---|---|
| `LBDWH.V_T_MTH_AC_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_LN_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_CC_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_OD_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_INVMT_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_GUARANTEE_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_AC_RATING_DTL` | `PROC_DTE` + `AC_CODE` + `ORGL_CR_RATING_FLG` | one rating for one account, one month |
| `LBFRS9.T_MTH_FRS9_PARTY_MSTR` | `PROC_DTE` + `CIF_NO` | one customer (party), one month |
| `LBFRS9.T_MTH_FRS9_RDL_AC_DTL` | `PROC_DTE` + `UNIQUE_ID_NO` | one account, one month |
| `LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST` | `PROC_DTE` + `V_ACCOUNT_NUMBER` | one account, one month |
| `LBDWH.V_T_CIF_MSTR` | `CIF_NO` (current state; no `PROC_DTE`) | one customer, as held now |
| `LBDWH.T_MTH_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one currency, one month |
| `LBDWH.T_DAL_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one currency, one date |
| `LBFRS9.T_FRS9_PRD_MSTR` | `PRODUCT_HIERARCHY_CD` (static; no `PROC_DTE`) | one product-hierarchy code |

### Account keys — the FVOCI suffix and the `AC_CODE` trap

**Every layer carries two account identifiers: the grain key, which appends the
literal `FVOCI` on FVOCI accounts, and an unsuffixed twin.** **[C]**

| Layer | Grain key — **suffixed** | Twin — **unsuffixed** |
|---|---|---|
| 5 product input tables, `V_T_MTH_AC_DTL` | `AC_CODE` | `ORIGINAL_ACCOUNT_NUMBER` |
| `RDL_AC_DTL` | `UNIQUE_ID_NO` | `AC_CODE` |
| `RDL_MSTR_LIST` | `V_ACCOUNT_NUMBER` | `V_ORIGINAL_ACCOUNT_NUMBER` |

**`AC_CODE` means opposite things either side of the engine** — suffixed on the
product tables, unsuffixed on `RDL_AC_DTL`. A cross-layer join on
`AC_CODE = AC_CODE` silently drops every FVOCI account. Join suffixed-to-suffixed
(`LN_DTL.AC_CODE = RDL_AC_DTL.UNIQUE_ID_NO`) or unsuffixed-to-unsuffixed
(`LN_DTL.ORIGINAL_ACCOUNT_NUMBER` to the DWH view). **[C]**

An FVOCI account appears in the product tables **once**, as `...FVOCI` only —
no plain twin row, so nothing summing a product table double-counts it. **[C]**

`T_FRS_RT_INTF.AC_CODE` and `T_MTH_FRS9_RT_DTL.AC_CODE` are **suffixed**. **[C]**
Whether `EIR_ADJ_SCH.ACCOUNT_NUMBER` is suffixed is **[O]** — it joins to
`LN_DTL.AC_CODE`, so if not, FVOCI accounts in the pool drop.

### Other table-level facts

`ECL Flux` (§11.10) takes the borrower name from this view but
`MKT_SUB_SEG_DESC` from `PARTY_MSTR`, so it carries a name as held now against a
segment as at the reporting date. A borrower renamed since month-end shows the
new name against the old segment. **[C]**

**FX — `EXCHG_RT` is one unit of foreign currency in SGD.** Convert to SGD by
**multiplying**, back out by dividing. Same on `T_MTH_CURCY_EXCHG` and
`T_DAL_CURCY_EXCHG`. **[C]**

> An earlier note recorded the **opposite** convention and was wrong despite a
> **[C]** marker. Confirmed from 30JUN2026: `KWD 4.2054`, `USD 1.2948`,
> `BND 1.0000` (pegged 1:1 to SGD, which only reads right under multiply).

**Variant currency codes sit alongside the standard ones.** At 30JUN2026: `CNO`
and `CNH` beside `CNY`; `INO`/`INH`, `KRO`/`KRH`, `TWO`, `IDO`/`IDH`, `MYO`,
`PHO`/`PHH`, `THO`/`THH`, `VNO` beside their bases. Rates are sometimes
identical, sometimes slightly different; `CNH` is the offshore renminbi code, so
these look like onshore/offshore book splits. **[I]** on `O` and `H`.

This bites wherever `CURCY_CODE` is a grouping or join key, since a variant and
its base are unrelated currencies: a `CNY` benchmark will not match a `CNO`
account, and a journal keyed on the code posts them as separate lines. Whether
any account carries a variant code is **[O]**.

**Ratings (`T_MTH_FRS9_AC_RATING_DTL`)** — up to two rows per account per month
on `ORGL_CR_RATING_FLG`: `Y` = origination, `N` = current.

**`RDL_AC_DTL.GL_AC_ID` is segment 4 of the EGL account string.** It reproduces
`GL_CODE` from the product input tables **[I]**, so it is source-held, not
derived:

- **Loans and guarantees: `00000`** — the **posting convention, not a defect**.
  ECL on a loan genuinely posts `00000` in segment 4. **[C]**
- **Investments: a real product code**, so RDL yields the segment-4-to-product
  mapping for investments (`57131` → `SG_REVRPO`, `58313` → the five bond
  products) but not for loans. **[C]**
- **NOSTRO, from Jul26: `00000`.** The §12 spec sets `INVMT_DTL.GL_CODE` to a
  literal `00000`, so "investments carry a real product code" no longer holds
  table-wide. **[C]**

**`LCY_LEDGER_BAL` is the only ledger balance on `RDL_AC_DTL` — no RCY twin.**
The nearest RCY column, `RCY_CUR_PAR_BAL`, is a different concept: current par
balance. Whether the two are an LCY/RCY pair is **[O]** — testable by checking
they match for SGD accounts and their ratio equals `EXCHG_RT` for the rest.
Until then, the ledger balance in account currency must be derived by dividing
by `EXCHG_RT`. **[C]**

**`T_FRS_RT_INTF` — rate interface.** Not a `T_MTH_` table but still monthly by
`PROC_DTE`. Several rows per account, each with an `RT_EFF_DTE` and a
`PRM_RT_NO` peg code, so dedupe to the latest row before use. `PRM_RT_NO`
**90 = 1-month SORA, 91 = 3-month SORA**; other codes exist (52 seen). An
account that has moved off SORA still carries its old 90/91 rows underneath, so
apply the peg filter **after** the dedupe, never in the read. `RT_EFF_DTE` can
be **after** the reporting date — these are future-scheduled rates. **[C]**

**`T_MTH_FRS9_RT_DTL` — rate tiers.** One row per account per rate period, so a
fixed-then-floating loan carries both its fixed and floating tiers. `RT_EFF_DTE`
and `RT_END_DTE` are **datetimes** — a date format overflows to asterisks.
`TIER_INT_RT` = `BASE_RT` + `VAR_RT`. **[C]**

**On a fixed-then-floating loan inside its fixed period, `LN_DTL.BASE_RT` holds
the SORA rate the account is pegged to, not the fixed rate it charges.**
`RT_TYP_DESC` reads `FIXED RATE` throughout. **[C]**

**`RDL_AC_DTL.SRC_PROD_TYPE_CD` is the `PRD_CODE`** carried through from the
product files, so RDL rows tie back to a product without joining the input
tables. **[C]**

**`RDL_AC_DTL.LEGAL_ENTITY` uses the `CO_CODE` convention — `001` / `003`** —
not the `MBB-SG` / `MSL` strings the product input tables carry on
`LEGAL_ENTITY_CODE`. Matters wherever RDL is joined or patched on entity. **[C]**

**Market segment lives on both `RDL_AC_DTL` and `PARTY_MSTR`, either usable.**
The trap: the description column names are **transposed** between them
(`SUB_MKT_SEG_DESC` against `MKT_SUB_SEG_DESC`), easily misread as absent. **[C]**
The value domain of `MKT_SUB_SEG_DESC` is not recorded anywhere in this pack and
differs from `MKT_SUB_SEGMENT` on `RDL_MSTR_LIST`, whose six labels are in
`LBFRS9_T_MTH_FRS9_RDL_MSTR_LIST__MKT_SUB_SEGMENT.txt`. §11.10 filters on a
value by literal, so the domain matters — `Open_Items.md` item 10. **[O]**

### EIR columns on RDL

`RDL_AC_DTL` carries four EIR amounts; **only `LCY_EIR_ADJ_AMT` is used**:

| Column | Content |
|---|---|
| `LCY_EIR_ADJ_AMT` | the EIR adjustment **balance** |
| `LCY_EIR_ADJ_OPENING_AMT` | opening balance |
| `LCY_EIR_ADJ_FY_AMT` | financial-year movement |
| `LCY_EIR_ADJ_FTM_AMT` | movement for the month |

**EIR is the exception to the `FY` convention in §2 — a balance, not a
year-to-date movement.** So the posting is whole-balance-and-reverse rather than
movement-based (mechanics: `MER_00` §7), and `LCY_EIR_ADJ_AMT` is the right
field for balance-meets-balance checks against an accumulated trial balance. The
other three are **not** substitutes. **[C]**

**`FY_AMT` and `FTM_AMT` are derived from `AMT`, not independently sourced.**
Patch `LCY_EIR_ADJ_AMT` and the loader recomputes both, so a patch file carries
the balance alone and is still complete. **[C]** It follows that
`OPENING_AMT + FY_AMT = AMT` holds by construction, testable only to **2dp**
given the differing decimal formats. Whether `OPENING_AMT` is the 31 December or
prior-month balance is **[O]**, and matters only across a year end.

**The same holds for ECL patches on the LCY side only.** Send
`LCY_ECL_CLOSING_FY` and the LCY movement columns derive. **[C]**

> **The RCY twins are not derived.** The loader does not recompute
> `RCY_ECL_CHARGE_FY`, `RCY_ECL_WRITEBACK_FY` or the `FTM` pair from a patched
> `RCY_ECL_CLOSING_FY`, so an RCY patch must carry them explicitly. **[C]** This
> matters because `Post-Posting TB Recon` (§11.9) reconciles on the four RCY
> **component** columns, not closing — a closing-only RCY patch breaks that
> recon on every patched account. Whether the LCY derivation reaches the `FTM`
> pair, and splits charge against writeback the same way, is **[O]**.

`RDL_MSTR_LIST` carries the engine-native `EIR`, `EIR_OPENING` and
`EIR_PREVIOUS`. **`EIR_PREVIOUS` is the prior month's balance** — the figure
HO's reversal file should carry, which would let `EGL Reversal Check` test the
EIR leg against a stated amount rather than last month's posting. **[I]**, unused.

### Fair value columns on RDL

`RDL_AC_DTL` carries `RCY_FAIR_VALUE` and `LCY_FAIR_VALUE`, with
`SEC_CLS_CD = 'FVOCI'` marking the rows they apply to.

**The engine does not compute these — Singapore does and patches them in**
(`FVOCI Loan MTM`, §11.12). Two things depend on them landing: next month's
reversal reads `RCY_FAIR_VALUE` back off RDL rather than recomputing, and
`Post-Posting TB Recon` (§11.9) uses it as the expected FVOCI GL balance. That
second dependency is the **control** — a patch that never loads surfaces as an
FVOCI break in the same cycle, not silently. **[C]**

### Opening-balance FX columns — not understood

`ECL_OPENING_REVAL_RCY`, `ECL_OPENING_FX_DIFF`, `ECL_OPENING_FX_DIFF_FTM`,
`UWI_OPENING_REVAL_RCY` and `UWI_OPENING_FX_DIFF` on `RDL_AC_DTL`. No process
reads them; whether they are posted or informational is **[O]** — relevant
because `Post-Posting TB Recon` reconciles the opening GL against
`RCY_ECL_OPENING_BAL` alone and records that openings always differ at account
level.

### GL columns stated on RDL

The `GL_ID_*` columns beside each amount are **unused** — every process takes
the GL from the EGL Mapping instead. Comparing the two would independently
confirm the mapping. **[C]**

### Local schedule table — `EIR_ADJ_SCH`

Not an FRS9 table. `BASE.EIR_ADJ_SCH` in `My SAS Files` is the **source of
truth**; `LBDSFAU.EIR_ADJ_SCH` is a full mirror overwritten each month. **[C]**

| Grain | One row = |
|---|---|
| `PROC_DTE` + `ACCOUNT_NUMBER` | one pool account, one month |

The key column is `ACCOUNT_NUMBER`, not `AC_CODE` — it joins to
`LN_DTL.AC_CODE`. It holds a **closed pool** of MSL accounts (the historical AEL
catch-up), so it only shrinks; see §11.11. **[C]**

### Local schedule table — `FUT_REPRICING_<yymm>`

Not an FRS9 table. In `FUTREP` = `My SAS Files\futrep`. **One dataset per
month**, tagged from `PROC_DTE`, e.g. `FUT_REPRICING_2606`. Written by
`EIR Future Repricing Adjustment` and read back next month as the reversal
(§11.13). **[C]**

| Grain | One row = |
|---|---|
| `AC_CODE` (one month per dataset) | one future-tagged account, one month |

| Column | Note |
|---|---|
| `PROC_DTE` | month end, **datetime** not date |
| `AC_CODE` | joins to `RDL_AC_DTL.UNIQUE_ID_NO`, so suffixed |
| `PRD_CODE` | one of the four housing-loan codes |
| `REPRICE_DATE` | later than `PROC_DTE` by construction |
| `BIZ_UNIT_CODE` | becomes `COST_CENTRE` on the entry |
| `FINANCING_CODE` | `C` / `I`; drives `SUB_ACCOUNT` |
| `CURR_MTH_EIR` | `LCY_EIR_ADJ_AMT` this month, missing coalesced to 0 |
| `PREV_MTH_EIR` | prior month, the figure the RDL patch holds at |
| `EIR_DIFF` | current less prior; rows rounding to zero are excluded |

Unlike `EIR_ADJ_SCH` — a single accumulating table with a mirror — this is
month-per-dataset with none, which makes the write idempotent: a rerun
overwrites only its own month. **[C]** The oldest month, migrated from Excel,
carries narrower character widths than the `LN_DTL`-native months. Nothing
appends months together, so this is harmless unless someone stacks them. **[C]**

`LN_DTL` also carries `REPRICE_FLAG` beside `REPRICE_DATE`; the process selects
on the date alone and whether the flag is redundant is **[O]**.

### Master listing extract — `MTH.MASTERLISTING_<yymm>`

Not an FRS9 table. A local per-month copy of the master listing HO returns, held
in the month output folder. A **fallback source** for the four `RDL_MSTR_LIST`
fields the account string and EGL Mapping key need, when `RDL_MSTR_LIST` has not
yet loaded. One month only, so no date filter. Column names match
`RDL_MSTR_LIST`. **[C]**

### Product hierarchy master (`T_FRS9_PRD_MSTR`)

Keyed on `PRODUCT_HIERARCHY_CD`, joined from each consuming table's product-code
field:

| Consuming table | Join field → `PRODUCT_HIERARCHY_CD` |
|---|---|
| 5 product input tables | `PRD_CODE` |
| `RDL_AC_DTL` | `SRC_PROD_TYPE_CD` |
| `RDL_MSTR_LIST` | `V_PROD_CODE` |

`SG_NOSTRO` maps to `LEVEL_3 = Cash and STF`. **[C]** The EGL Mapping lookup
joins from `SRC_PROD_TYPE_CD`, not `PRD_CODE`, so a NOSTRO row resolves only if
the engine carries `SG_NOSTRO` through to `RDL_AC_DTL`.

### Securities classification (`SEC_CLS_CD`)

On `RDL_AC_DTL` only. The product input tables carry `IFRS9_CLASS_CODE` and the
engine derives one from the other — so a spec needing `AMRTCOST` or `FVOCI` on
RDL sets `IFRS9_CLASS_CODE` on the input, as the NOSTRO spec does (§12 field
17). **[C]**

---

## 2. Structural facts about RDL

- **RDL accumulates through the year.** An account closed in an earlier month
  still appears in every later month. The five product files are the opposite —
  point-in-time, so a closed account appears in the month it closed and not
  after. **[C]** Hence the ECL Flux filter on non-zero current-month P&L: by
  mid-year most RDL rows are dormant. Any process taking every row under a
  customer also picks up long-closed accounts at nil balance.
- **`FY` is year-to-date, `FTM` is the month.** ECL and UWI postings use `FY`;
  flux analysis uses `FTM`. EIR is the exception — see above.
- **RCY and LCY have different sign conventions.** `LCY_ECL_WRITEBACK_FTM` is
  already negative; `RCY_ECL_WRITEBACK_FTM` is positive. Swapping a column for
  its twin without changing the arithmetic silently doubles the figure. **[C]**
  All four RCY ECL components are positive magnitudes, and any hand-built RCY
  patch must respect that.
- **The component identity.** In RCY terms, with all four components positive:
  `CLOSING = OPENING + CHARGE − WRITEBACK − WRITEOFF`. `ECL Manual Override`
  (§11.15) checks it on the accounts it touches and derives the required year
  movement as `target − opening + write-off`. Whether it holds across the whole
  table is **[O]**.
- **A month's absence from a `T_MTH_` table cannot be probed with `OBS=`.** A
  `datepart(PROC_DTE)` filter does not push down to Oracle, so the engine
  applies the row limit and SAS filters afterwards — `obs=1` tests one arbitrary
  physical row. Count over a datetime range on the raw column instead. **[C]**
- **That non-pushdown costs 4×–14× elapsed** (measured Aug26, identical rows
  out). Step shape does not matter — `SET`, `PROC SORT` and `PROC SQL` all
  gained, including `PROC SQL` joins of an Oracle table to a WORK table. The gap
  widens by one month's rows every cycle. The log tells you which ran: fast runs
  print the literals in the `WHERE` sent to Oracle, slow ones print
  `DATEPART(PROC_DTE)=24318`. **[C]**
- **Which tables retain months.** `RDL_MSTR_LIST`, `RDL_AC_DTL`, the five
  product tables, `T_FRS_RT_INTF`, `RT_DTL` and `LBDWH.T_DAL_CURCY_EXCHG` all
  do. Separate from the point-in-time property of the product files, which is
  about **account** presence within a month. **[C]**
- **Standing rule: filter `PROC_DTE` with bounded datetime literals** on every
  `LBFRS9` and `LBDWH` table. Bounded (`>= month end`, `< next day`) rather than
  equality, so a non-midnight timestamp cannot be missed. Rollout status:
  `Open_Items.md` item 13. **[C]**

  Two `datepart()` uses are **not** covered and should stay: a filter on a WORK
  table, which has no database to push to, and `datepart()` as a conversion in
  an assignment rather than a filter. **[C]**
