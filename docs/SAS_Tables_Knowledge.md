# FRS9 / DWH Table Reference

Grains, keys, join paths and the conventions that change how code must be
written. Scope is the tables only — what a process *does* with them is in the
`MER_*` files.

Facts here are confirmed unless marked **[I]** inferred or **[O]** open.

---

## 1. Model

    LBDWH tables → product INPUT tables → ECL engine → RDL_MSTR_LIST → RDL_AC_DTL

Monthly IFRS 9 / MFRS 9 Expected Credit Loss reporting. `RDL_MSTR_LIST` is
engine-native; `RDL_AC_DTL` is the business-named layer derived from it. Both
sit in `LBFRS9` alongside the input tables.

The five **product input tables** are `LN_DTL`, `CC_DTL`, `OD_DTL`,
`INVMT_DTL`, `GUARANTEE_DTL` — referred to collectively throughout.

---

## 2. Grain

`PROC_DTE` is the month-end date and part of the key on every table but the two
noted. Snapshots are retained month-on-month, so **every query needs a
`PROC_DTE` filter** (§5).

| Table | Grain | Notes |
|---|---|---|
| `LBFRS9.T_MTH_FRS9_LN_DTL` | `PROC_DTE` + `AC_CODE` | point-in-time |
| `LBFRS9.T_MTH_FRS9_CC_DTL` | `PROC_DTE` + `AC_CODE` | point-in-time |
| `LBFRS9.T_MTH_FRS9_OD_DTL` | `PROC_DTE` + `AC_CODE` | point-in-time |
| `LBFRS9.T_MTH_FRS9_INVMT_DTL` | `PROC_DTE` + `AC_CODE` | point-in-time |
| `LBFRS9.T_MTH_FRS9_GUARANTEE_DTL` | `PROC_DTE` + `AC_CODE` | point-in-time |
| `LBDWH.V_T_MTH_AC_DTL` | `PROC_DTE` + `AC_CODE` | `AC_CODE` here is **unsuffixed** |
| `LBFRS9.T_MTH_FRS9_RDL_AC_DTL` | `PROC_DTE` + `UNIQUE_ID_NO` | accumulates (§3) |
| `LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST` | `PROC_DTE` + `V_ACCOUNT_NUMBER` | accumulates (§3) |
| `LBFRS9.T_MTH_FRS9_PARTY_MSTR` | `PROC_DTE` + `CIF_NO` | one party |
| `LBFRS9.T_MTH_FRS9_AC_RATING_DTL` | `PROC_DTE` + `AC_CODE` + `ORGL_CR_RATING_FLG` | **2 rows per account**: `Y` origination, `N` current |
| `LBFRS9.T_MTH_FRS9_RT_DTL` | `PROC_DTE` + `AC_CODE` + rate period | **many rows per account** |
| `T_FRS_RT_INTF` | `PROC_DTE` + `AC_CODE` + `RT_EFF_DTE` | **many rows per account**; dedupe (§4) |
| `LBDWH.T_MTH_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one rate per month |
| `LBDWH.T_DAL_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one rate per date |
| `LBDWH.V_T_CIF_MSTR` | `CIF_NO` | **no `PROC_DTE`** — current state |
| `LBFRS9.T_FRS9_PRD_MSTR` | `PRODUCT_HIERARCHY_CD` | **no `PROC_DTE`** — static |

**Point-in-time vs accumulating.** The product tables hold only accounts open in
that month. RDL keeps an account in every later month once it appears, so by
mid-year most RDL rows are dormant and any "all rows for this customer" query
picks up long-closed accounts at nil balance.

---

## 3. Joins

### The FVOCI suffix

Every account layer carries two identifiers: the grain key, which appends the
literal `FVOCI` on FVOCI accounts, and an unsuffixed twin.

| Layer | Grain key (**suffixed**) | Twin (**unsuffixed**) |
|---|---|---|
| 5 product input tables | `AC_CODE` | `ORIGINAL_ACCOUNT_NUMBER` |
| `RDL_AC_DTL` | `UNIQUE_ID_NO` | `AC_CODE` |
| `RDL_MSTR_LIST` | `V_ACCOUNT_NUMBER` | `V_ORIGINAL_ACCOUNT_NUMBER` |
| `LBDWH.V_T_MTH_AC_DTL` | — | `AC_CODE` |

**`AC_CODE` means opposite things either side of the engine** — suffixed on the
product tables, unsuffixed on `RDL_AC_DTL`. Joining `AC_CODE = AC_CODE` across
that boundary silently drops every FVOCI account. Match suffixed to suffixed, or
unsuffixed to unsuffixed, never across.

An FVOCI account appears in the product tables **once**, as `...FVOCI` only —
there is no plain twin row, so summing a product table cannot double-count it.

### Join map

Add `PROC_DTE` to every join below except those to `V_T_CIF_MSTR` and
`T_FRS9_PRD_MSTR`, which have none.

| From | To | On | Rows returned |
|---|---|---|---|
| product tables | `RDL_AC_DTL` | `AC_CODE` = `UNIQUE_ID_NO` | 1:1 |
| product tables | `V_T_MTH_AC_DTL` | `ORIGINAL_ACCOUNT_NUMBER` = `AC_CODE` | 1:1 |
| `RDL_AC_DTL` | `RDL_MSTR_LIST` | `UNIQUE_ID_NO` = `V_ACCOUNT_NUMBER` | 1:1 |
| product tables / `RDL_AC_DTL` | `PARTY_MSTR` | `CIF_NO` | many:1 |
| `RDL_AC_DTL` | `V_T_CIF_MSTR` | `CIF_NO` | many:1 |
| product tables | `AC_RATING_DTL` | `AC_CODE` | **1:2** — filter `ORGL_CR_RATING_FLG` |
| `LN_DTL` | `RT_DTL` | `AC_CODE` (both suffixed) | **1:many** — one per rate period |
| `LN_DTL` | `T_FRS_RT_INTF` | `AC_CODE` (both suffixed) | **1:many** — dedupe first (§4) |
| product tables | `T_FRS9_PRD_MSTR` | `PRD_CODE` = `PRODUCT_HIERARCHY_CD` | many:1 |
| `RDL_AC_DTL` | `T_FRS9_PRD_MSTR` | `SRC_PROD_TYPE_CD` = `PRODUCT_HIERARCHY_CD` | many:1 |
| `RDL_MSTR_LIST` | `T_FRS9_PRD_MSTR` | `V_PROD_CODE` = `PRODUCT_HIERARCHY_CD` | many:1 |
| any | `CURCY_EXCHG` | `CURCY_CODE` | many:1 |
| `LN_DTL` | `EIR_ADJ_SCH` | `AC_CODE` = `ACCOUNT_NUMBER` | 1:1 |
| `LN_DTL` | `FUT_REPRICING_<yymm>` | `AC_CODE` | 1:1 |

`RDL_AC_DTL.SRC_PROD_TYPE_CD` is the product tables' `PRD_CODE` carried through,
so RDL rows resolve to a product without joining the input tables.

`SG_NOSTRO` maps to `LEVEL_3 = Cash and STF`. The EGL Mapping lookup joins from
`SRC_PROD_TYPE_CD`, so a NOSTRO row resolves only if the engine carries
`SG_NOSTRO` through to `RDL_AC_DTL`.

### Entity codes differ by layer

`RDL_AC_DTL.LEGAL_ENTITY` uses `CO_CODE` values `001` / `003`. The product input
tables use `MBB-SG` / `MSL` on `LEGAL_ENTITY_CODE`. Translate when joining or
filtering on entity across layers.

---

## 4. Column semantics

Facts that change arithmetic or filter logic. Anything derivable from
`PROC CONTENTS` is deliberately not repeated here.

### Currency

`EXCHG_RT` is **one unit of foreign currency expressed in SGD**. Convert to SGD
by **multiplying**; back out by dividing. Same on the monthly and daily tables.

`RDL_AC_DTL.LCY_LEDGER_BAL` is the only ledger balance — there is no RCY twin,
so the account-currency figure must be derived by dividing by `EXCHG_RT`. The
adjacent `RCY_CUR_PAR_BAL` is a **different concept** (current par balance) and
is not a substitute. Whether the two are in fact an LCY/RCY pair is **[O]** —
testable by checking they match for SGD accounts and their ratio equals
`EXCHG_RT` for the rest.

### Sign conventions

**RCY and LCY signs differ.** `LCY_ECL_WRITEBACK_FTM` is already negative;
`RCY_ECL_WRITEBACK_FTM` is positive. All four RCY ECL components are positive
magnitudes. Swapping a column for its twin without changing the arithmetic
silently doubles the figure.

RCY component identity, all components positive:

    CLOSING = OPENING + CHARGE − WRITEBACK − WRITEOFF

Whether it holds across the whole table is **[O]**.

### Period conventions

`FY` is year-to-date, `FTM` is the month alone. **EIR is the exception — a
balance, not a movement.** `RDL_AC_DTL` carries four EIR columns:

| Column | Content |
|---|---|
| `LCY_EIR_ADJ_AMT` | the EIR **balance** — the field to use |
| `LCY_EIR_ADJ_OPENING_AMT` | opening balance |
| `LCY_EIR_ADJ_FY_AMT` | financial-year movement |
| `LCY_EIR_ADJ_FTM_AMT` | movement for the month |

`OPENING_AMT + FY_AMT = AMT` holds by construction, testable only to **2dp**
given the differing decimal formats. Whether `OPENING_AMT` is the 31 December or
the prior-month balance is **[O]**, and matters only across a year end.

`RDL_MSTR_LIST` carries engine-native `EIR`, `EIR_OPENING` and `EIR_PREVIOUS`.
`EIR_PREVIOUS` is the prior month's balance. **[I]**

### Which columns the loader derives

Patching `LCY_EIR_ADJ_AMT` makes the loader recompute `FY_AMT` and `FTM_AMT`, so
an EIR patch file carries the balance alone and is still complete. The same
holds for `LCY_ECL_CLOSING_FY` on the LCY side.

**The RCY twins are not derived.** `RCY_ECL_CHARGE_FY`, `RCY_ECL_WRITEBACK_FY`
and the `FTM` pair are not recomputed from a patched `RCY_ECL_CLOSING_FY`, so an
RCY patch must carry them explicitly. Whether the LCY derivation reaches the
`FTM` pair, and splits charge against writeback the same way, is **[O]**.

### Rates

`T_FRS_RT_INTF` — **dedupe to the latest `RT_EFF_DTE` per account before use.**
`PRM_RT_NO` is the peg code: **90 = 1-month SORA, 91 = 3-month SORA**; others
exist (52 seen). An account that has moved off SORA still carries its old 90/91
rows underneath, so apply the peg filter **after** the dedupe, never in the read.
`RT_EFF_DTE` can be later than the reporting date — these are future-scheduled.

`RT_DTL` — `TIER_INT_RT` = `BASE_RT` + `VAR_RT`. `RT_EFF_DTE` and `RT_END_DTE`
are **datetimes**; a date format overflows to asterisks.

`LN_DTL.BASE_RT` on a fixed-then-floating loan inside its fixed period holds the
**SORA rate it is pegged to, not the fixed rate it charges**, while
`RT_TYP_DESC` reads `FIXED RATE` throughout.

### Not understood

`ECL_OPENING_REVAL_RCY`, `ECL_OPENING_FX_DIFF`, `ECL_OPENING_FX_DIFF_FTM`,
`UWI_OPENING_REVAL_RCY`, `UWI_OPENING_FX_DIFF` on `RDL_AC_DTL`. Unused; whether
posted or informational is **[O]**.

---

## 5. Query rules

**Filter `PROC_DTE` with bounded datetime literals** on every `LBFRS9` and
`LBDWH` table — `>= month end` and `< next day`, rather than equality, so a
non-midnight timestamp cannot be missed.

`datepart(PROC_DTE)` **does not push down to Oracle**. SAS pulls every retained
month and filters locally, costing 4×–14× elapsed regardless of step type
(`SET`, `PROC SORT`, `PROC SQL` all measured Aug26), and the gap widens each
cycle. The log confirms which ran: literals appear in the `WHERE` sent to
Oracle, `datepart()` appears as `DATEPART(PROC_DTE)=24318`.

Two `datepart()` uses are **fine and should stay**: filtering a WORK table, which
has no database to push to, and `datepart()` as a conversion in an assignment
rather than a filter.

**A month's absence cannot be probed with `OBS=`.** Because the filter does not
push down, the engine applies the row limit first and SAS filters afterwards, so
`obs=1` tests one arbitrary physical row. Count over a datetime range on the raw
column instead.

Tables confirmed to retain months: `RDL_MSTR_LIST`, `RDL_AC_DTL`, the five
product tables, `T_FRS_RT_INTF`, `RT_DTL`, `LBDWH.T_DAL_CURCY_EXCHG`.

---

## 6. Local datasets (not FRS9)

### `EIR_ADJ_SCH`

`BASE.EIR_ADJ_SCH` in `My SAS Files` is the source of truth;
`LBDSFAU.EIR_ADJ_SCH` is a full mirror overwritten each month.

| Grain | Notes |
|---|---|
| `PROC_DTE` + `ACCOUNT_NUMBER` | key column is `ACCOUNT_NUMBER`, joins to `LN_DTL.AC_CODE` |

A **closed pool** of MSL accounts, so it only shrinks. Whether
`ACCOUNT_NUMBER` carries the FVOCI suffix is **[O]** — if not, FVOCI accounts
in the pool drop from the join.

### `FUT_REPRICING_<yymm>`

In `FUTREP` = `My SAS Files\futrep`. **One dataset per month**, tagged from
`PROC_DTE` (e.g. `FUT_REPRICING_2606`) — so a rerun overwrites only its own
month.

| Grain | Notes |
|---|---|
| `AC_CODE`, one month per dataset | suffixed, joins to `RDL_AC_DTL.UNIQUE_ID_NO` |

| Column | Note |
|---|---|
| `PROC_DTE` | month end, **datetime** not date |
| `PRD_CODE` | one of the four housing-loan codes |
| `REPRICE_DATE` | later than `PROC_DTE` by construction |
| `BIZ_UNIT_CODE` | becomes `COST_CENTRE` on the entry |
| `FINANCING_CODE` | `C` / `I`; drives `SUB_ACCOUNT` |
| `CURR_MTH_EIR` | `LCY_EIR_ADJ_AMT` this month, missing coalesced to 0 |
| `PREV_MTH_EIR` | prior month, the figure the RDL patch holds at |
| `EIR_DIFF` | current less prior; rows rounding to zero are excluded |

The oldest month, migrated from Excel, has narrower character widths than the
`LN_DTL`-native months — harmless unless the datasets are stacked.

`LN_DTL` also carries `REPRICE_FLAG` beside `REPRICE_DATE`; whether it is
redundant to the date is **[O]**.

### `MTH.MASTERLISTING_<yymm>`

Per-month copy of the master listing HO returns, in the month output folder.
A **fallback** for `RDL_MSTR_LIST` fields before that table loads. Holds one
month, so it needs no date filter; column names match `RDL_MSTR_LIST`.

---

## 7. The `.txt` companion files

| File | Contents |
|---|---|
| `LIBRARY_TABLENAME.txt` | `PROC CONTENTS` of one table — the authority on columns, types and lengths |
| `LIBRARY_TABLENAME__COLUMNNAME.txt` | derivation of one column, IT's Informatica logic restated in SAS |

**Search the `__COLUMN.txt` files before answering any lineage question** —
"where does this field come from", "is this field used anywhere". They are a
reference library, not a production workstream.
`FRS9_LN_DTL_pending_derivations.txt` lists columns not yet rebuilt.
`LBFRS9_T_MTH_RSME_CMPLX_PRD_WRK_TBL.txt` is a work table feeding the
`LN_DTL.ALLOCATED_COST` derivation, not part of the monthly flow.

Two defects run through the library, fixed in `V_SEGMENT_NAME` only: unbounded
`datepart(PROC_DTE)` filters (§5), and hash lookup variables typed numeric by
accident (trap and fix in the sas-writing skill).
