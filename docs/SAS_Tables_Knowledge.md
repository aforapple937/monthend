# Data Dictionary

Grain, join map, column rules. Facts are confirmed unless **[I]** inferred or
**[O]** open. Column inventory (names, types, lengths) is in the `.txt` files
(§7), not here.

    LBDWH → product INPUT tables → ECL engine → RDL_MSTR_LIST → RDL_AC_DTL

**Product tables** = `LN_DTL`, `CC_DTL`, `OD_DTL`, `INVMT_DTL`,
`GUARANTEE_DTL` (all `LBFRS9.T_MTH_FRS9_*`).

---

## 1. Grain

`PROC_DTE` = month-end date; part of every key except where noted. All months
are retained — **every query needs a `PROC_DTE` filter** (§3).

| Table | Grain | Note |
|---|---|---|
| product tables (×5) | `PROC_DTE` + `AC_CODE` | point-in-time: present through the month it closes, absent after |
| `LBDWH.V_T_MTH_AC_DTL` | `PROC_DTE` + `AC_CODE` | `AC_CODE` **unsuffixed** here |
| `RDL_AC_DTL` | `PROC_DTE` + `UNIQUE_ID_NO` | accumulates YTD¹ |
| `RDL_MSTR_LIST` | `PROC_DTE` + `V_ACCOUNT_NUMBER` | accumulates YTD¹ |
| `PARTY_MSTR` | `PROC_DTE` + `CIF_NO` | |
| `AC_RATING_DTL` | `PROC_DTE` + `AC_CODE` + `ORGL_CR_RATING_FLG` | **2 rows/account**: `Y` orig, `N` current |
| `RT_DTL` | `PROC_DTE` + `AC_CODE` + rate period | **many rows/account** |
| `T_FRS_RT_INTF` | `PROC_DTE` + `AC_CODE` + `RT_EFF_DTE` | **many rows/account** |
| `LBDWH.T_MTH_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | monthly rate |
| `LBDWH.T_DAL_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | daily rate |
| `LBDWH.V_T_CIF_MSTR` | `CIF_NO` | **no `PROC_DTE`** — current state |
| `T_FRS9_PRD_MSTR` | `PRODUCT_HIERARCHY_CD` | **no `PROC_DTE`** — static |

¹ Once an account appears in RDL it stays in every later month, at nil balance
after closure.

---

## 2. Joins

### FVOCI suffix

Grain keys append literal `FVOCI` to the account number on FVOCI accounts;
each layer also carries an unsuffixed twin. **Join suffixed↔suffixed or
unsuffixed↔unsuffixed, never across** — `AC_CODE = AC_CODE` across the engine
silently drops every FVOCI account.

| Layer | Suffixed (grain) | Unsuffixed (twin) |
|---|---|---|
| product tables | `AC_CODE` | `ORIGINAL_ACCOUNT_NUMBER` |
| `RDL_AC_DTL` | `UNIQUE_ID_NO` | `AC_CODE` |
| `RDL_MSTR_LIST` | `V_ACCOUNT_NUMBER` | `V_ORIGINAL_ACCOUNT_NUMBER` |
| `V_T_MTH_AC_DTL` | — | `AC_CODE` |

FVOCI accounts appear **once** in the product tables (`...FVOCI` row only) —
no double-count risk when summing.

### Join map

Include `PROC_DTE` in every join except to `V_T_CIF_MSTR` and
`T_FRS9_PRD_MSTR`.

| From | To | On | Cardinality |
|---|---|---|---|
| product tables | `RDL_AC_DTL` | `AC_CODE` = `UNIQUE_ID_NO` | 1:1 |
| product tables | `V_T_MTH_AC_DTL` | `ORIGINAL_ACCOUNT_NUMBER` = `AC_CODE` | 1:1 |
| `RDL_AC_DTL` | `RDL_MSTR_LIST` | `UNIQUE_ID_NO` = `V_ACCOUNT_NUMBER` | 1:1 |
| product tables / `RDL_AC_DTL` | `PARTY_MSTR` | `CIF_NO` | many:1 |
| `RDL_AC_DTL` | `V_T_CIF_MSTR` | `CIF_NO` | many:1 |
| product tables | `AC_RATING_DTL` | `AC_CODE` | **1:2** — filter `ORGL_CR_RATING_FLG` |
| `LN_DTL` | `RT_DTL` | `AC_CODE` | **1:many** |
| `LN_DTL` | `T_FRS_RT_INTF` | `AC_CODE` | **1:many** — dedupe first |
| product tables | `T_FRS9_PRD_MSTR` | `PRD_CODE` = `PRODUCT_HIERARCHY_CD` | many:1 |
| `RDL_AC_DTL` | `T_FRS9_PRD_MSTR` | `SRC_PROD_TYPE_CD` = `PRODUCT_HIERARCHY_CD` | many:1 |
| `RDL_MSTR_LIST` | `T_FRS9_PRD_MSTR` | `V_PROD_CODE` = `PRODUCT_HIERARCHY_CD` | many:1 |
| any | `CURCY_EXCHG` | `CURCY_CODE` | many:1 |
| `LN_DTL` | `EIR_ADJ_SCH` | `AC_CODE` = `ACCOUNT_NUMBER` | 1:1 |
| `LN_DTL` | `FUT_REPRICING_<yymm>` | `AC_CODE` | 1:1 |

---

## 3. Query rules

| # | Rule |
|---|---|
| Q1 | Filter `PROC_DTE` with **bounded datetime literals**: `>= month end` and `< next day`. Never equality (non-midnight timestamps), never `datepart()` |
| Q2 | `datepart(PROC_DTE)` does not push down to Oracle — SAS pulls all retained months and filters locally: 4×–14× elapsed, worsening monthly. Log check: fast = literals in the `WHERE` sent to Oracle; slow = `DATEPART(PROC_DTE)=…` |
| Q3 | `datepart()` stays fine on WORK tables and as a conversion in assignments — only database filters are affected |
| Q4 | Never probe a month's presence with `OBS=` — the row limit applies before the local filter, so `obs=1` tests one arbitrary row. Count over a datetime range instead |

Confirmed month-retaining: `RDL_MSTR_LIST`, `RDL_AC_DTL`, product tables,
`T_FRS_RT_INTF`, `RT_DTL`, `T_DAL_CURCY_EXCHG`.

---

## 4. Local datasets (non-FRS9)

| Dataset | Location | Grain | Note |
|---|---|---|---|
| `EIR_ADJ_SCH` | `BASE` (`My SAS Files`) = source of truth; `LBDSFAU` = monthly-overwritten mirror | `PROC_DTE` + `ACCOUNT_NUMBER` | Closed, shrinking pool of MSL accounts. Key joins to `LN_DTL.AC_CODE`; FVOCI-suffixed? **[O]** |
| `FUT_REPRICING_<yymm>` | `FUTREP` = `My SAS Files\futrep` | `AC_CODE`, **one dataset per month** | Suffixed; joins to `RDL_AC_DTL.UNIQUE_ID_NO`. Rerun overwrites own month only. Oldest month has narrower char widths — don't stack |
| `MTH.MASTERLISTING_<yymm>` | month output folder | one month per dataset | Fallback for `RDL_MSTR_LIST` fields before it loads; same column names; no date filter needed |

`FUT_REPRICING` columns: `PROC_DTE` (**datetime** month end), `PRD_CODE` (4
housing-loan codes), `REPRICE_DATE` (> `PROC_DTE`), `BIZ_UNIT_CODE` (→
`COST_CENTRE`), `FINANCING_CODE` (`C`/`I` → `SUB_ACCOUNT`), `CURR_MTH_EIR`
(= `LCY_EIR_ADJ_AMT`, missing → 0), `PREV_MTH_EIR`, `EIR_DIFF` (zero-rounded
rows excluded). `LN_DTL.REPRICE_FLAG` beside `REPRICE_DATE`: redundant? **[O]**

---

## 5. Companion `.txt` files

| File pattern | Contents |
|---|---|
| `LIBRARY_TABLE.txt` | `PROC CONTENTS` — the authority on columns, types, lengths |
| `LIBRARY_TABLE__COLUMN.txt` | one column's derivation (IT's Informatica logic in SAS) — **search before any lineage question** |
| `FRS9_LN_DTL_pending_derivations.txt` | columns not yet rebuilt |
| `LBFRS9_T_MTH_RSME_CMPLX_PRD_WRK_TBL.txt` | work table for `LN_DTL.ALLOCATED_COST`; not in the monthly flow |

Library-wide defects (fixed in `V_SEGMENT_NAME` only): unbounded
`datepart(PROC_DTE)` filters (§3), hash lookup variables typed numeric (fix in
the sas-writing skill).
