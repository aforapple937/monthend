# SAS Tables Knowledge

Where the data lives: the FRS9/DWH tables, their grains, keys and conventions.
The reporting processes that consume these tables are the `MER_*` files —
one per stored process, mapped in `FRS9_Work_Reference.md`.

Status markers: **[C]** confirmed, **[I]** inferred, **[O]** open.

## The `.txt` companion files

Two kinds, distinguished by the double underscore:

| File | Contents |
|---|---|
| `LIBRARY_TABLENAME.txt` | `PROC CONTENTS` of one table |
| `LIBRARY_TABLENAME__COLUMNNAME.txt` | the derivation of one column, rebuilt in SAS |

The `__COLUMN.txt` files are a **lineage library, kept for reference, not a
production workstream.** They restate IT's Informatica derivations in SAS form
so questions like "where does this field come from" or "is this field used
anywhere" can be answered from the project rather than by asking IT. Search
them before answering any lineage question. **[C]**

`FRS9_LN_DTL_pending_derivations.txt` lists the columns not yet rebuilt.
`LBFRS9_T_MTH_RSME_CMPLX_PRD_WRK_TBL.txt` is a work table feeding the
`LN_DTL.ALLOCATED_COST` derivation — part of the same library, not a table in
the monthly flow. **[C]**

**Two known defects across the library** — fixed in `V_SEGMENT_NAME` only;
every other `__COLUMN.txt` file still carries them, so expect them when
running one for the first time. **[C]**

1. **`datepart(PROC_DTE)` month filters** — correct, but slow; the fix is the
   bounded-literal standing rule in §2 below.
2. **Hash lookup variables typed numeric by accident.** A variable that appears
   only in a `RETAIN` list or in `CALL MISSING` — never in a `SET` — is created
   as numeric, so `definedone()` fails with `Type mismatch for data variable`
   against a character column in the lookup dataset. The fix is
   `if 0 then set <lookup dataset>;` placed after the `RETAIN` (which fixes
   column order) and before the main `SET`. Trap detail is in the sas-writing
   skill.

---

## 1. Data model

Monthly IFRS 9 / MFRS 9 Expected Credit Loss (ECL) reporting.

Data-warehouse tables in `LBDWH` feed the product input tables in `LBFRS9`, which feed the ECL engine; the engine writes the engine-native master list (`RDL_MSTR_LIST`), from which the business-named RDL reporting layer (`RDL_AC_DTL`) is derived. (`RDL_MSTR_LIST` and `RDL_AC_DTL` also sit in `LBFRS9`, but as engine output and reporting — not input tables.)

    DWH tables → INPUT tables → ECL engine → MSTR_LIST → RDL

### Tables

`PROC_DTE` is the month-end date; monthly snapshots are retained month-on-month. The two exceptions without a `PROC_DTE` are flagged in the grain column below.

| Table | Grain (unique key) | One row = |
|---|---|---|
| `LBDWH.V_T_MTH_AC_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_LN_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_CC_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_OD_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_INVMT_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_GUARANTEE_DTL` | `PROC_DTE` + `AC_CODE` | one account, one month |
| `LBFRS9.T_MTH_FRS9_AC_RATING_DTL` | `PROC_DTE` + `AC_CODE` + `ORGL_CR_RATING_FLG` | one rating (origination or current) for one account, one month |
| `LBFRS9.T_MTH_FRS9_PARTY_MSTR` | `PROC_DTE` + `CIF_NO` | one customer (party), one month |
| `LBFRS9.T_MTH_FRS9_RDL_AC_DTL` | `PROC_DTE` + `UNIQUE_ID_NO` | one account, one month |
| `LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST` | `PROC_DTE` + `V_ACCOUNT_NUMBER` | one account, one month |
| `LBDWH.V_T_CIF_MSTR` | `CIF_NO` (current state; no `PROC_DTE`) | one customer, as held now |
| `LBDWH.T_MTH_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one currency, one month |
| `LBDWH.T_DAL_CURCY_EXCHG` | `PROC_DTE` + `CURCY_CODE` | one currency, one date |
| `LBFRS9.T_FRS9_PRD_MSTR` | `PRODUCT_HIERARCHY_CD` (static; no `PROC_DTE`) | one product-hierarchy code |

### Account keys — the FVOCI suffix, and the `AC_CODE` name trap

**Every layer carries two account identifiers: the grain key, which appends the
literal `FVOCI` to the account number on FVOCI accounts, and a twin that does
not.** The grain key is always the suffixed one. **[C]**

| Layer | Grain key — **suffixed** | Twin — **unsuffixed** |
|---|---|---|
| 5 product input tables, `V_T_MTH_AC_DTL` | `AC_CODE` | `ORIGINAL_ACCOUNT_NUMBER` |
| `RDL_AC_DTL` | `UNIQUE_ID_NO` | `AC_CODE` |
| `RDL_MSTR_LIST` | `V_ACCOUNT_NUMBER` | `V_ORIGINAL_ACCOUNT_NUMBER` |

**The trap is that `AC_CODE` means opposite things either side of the engine** —
the suffixed grain key on the product tables, the unsuffixed twin on
`RDL_AC_DTL`. A cross-layer join written on `AC_CODE = AC_CODE` silently drops
every FVOCI account. The correct forms are suffixed-to-suffixed
(`LN_DTL.AC_CODE = RDL_AC_DTL.UNIQUE_ID_NO`, which is what
`EIR Future Repricing Adjustment` §11.13 and the `FVOCI Loan MTM` patch key
§11.12 both use) or unsuffixed-to-unsuffixed (`LN_DTL.ORIGINAL_ACCOUNT_NUMBER`
to the DWH view, since the DWH `AC_CODE` is unsuffixed). **[C]**

An FVOCI account appears in the product tables **once**, as `...FVOCI` only —
there is no plain twin row, so nothing summing a product table double-counts
it. **[C]**

`T_FRS_RT_INTF.AC_CODE` and `T_MTH_FRS9_RT_DTL.AC_CODE` are **suffixed**, so
the SORA patch's joins from `LN_DTL.AC_CODE` are correct. **[C]**
Whether `EIR_ADJ_SCH.ACCOUNT_NUMBER` is suffixed is **[O]** — it joins to
`LN_DTL.AC_CODE`, so if it is not, FVOCI accounts in the pool would drop.

### Other table-level facts

**`LBDWH.V_T_CIF_MSTR` — customer master, keyed on `CIF_NO` alone.** A current-state view, not a monthly snapshot: 127 columns, no `PROC_DTE`, and change is tracked by `UPDT_DTE` / `LAST_MAINT_DTE` instead. `Observations` reads as missing and there is no sort flag, both consistent with an ODBC view onto the source system rather than a retained `T_MTH_` table. So a name read from here is the name **as held now**, not as at the reporting date, and a CIF since purged from source is simply absent — `CIF_ACT_FLG` is on the view if a closed customer needs distinguishing from a lookup miss. **[C]**, July 2026. Contents in `LBDWH_V_T_CIF_MSTR.txt`.

**`CIF_NO` is `$7` on that view against `$50` on `PARTY_MSTR` and `RDL_AC_DTL`.** Reading it into a hash keyed off RDL is safe — the key takes the PDV variable's attributes, so the narrower value is blank-padded into the wider key and matches — but the view cannot hold a CIF longer than 7 characters, and any such borrower would have no name from this source. Whether one exists is the open question at `Open_Items.md` item 6. `UCIF_NO` on the same view is `$50` and may be where a longer identifier lives. **[I]**. `CIF_NAME` is `$80` here, against the `$255` that both `ECL Flux` and `Overlay Watchlist` declare downstream; `ECL Manual Override` declares `$80`, matching the source.

Four processes read the view: `ECL Flux` (§11.10), `FVOCI Loan MTM` (§11.12), `Overlay Watchlist` (§11.14) and `ECL Manual Override` (§11.15). `ECL Flux` takes the borrower name from this view but `MKT_SUB_SEG_DESC` from `PARTY_MSTR` — so that report carries a name as held now against a sub-segment as at the reporting date, and a borrower renamed since month-end shows the new name against the old segment. **[C]**

**FX rates — `EXCHG_RT` is one unit of the foreign currency expressed in SGD.** So a foreign-currency amount converts to SGD by **multiplying** by the rate, and back out by dividing. Same convention on `T_MTH_CURCY_EXCHG` (monthly) and `T_DAL_CURCY_EXCHG` (daily). **[C]**

> An earlier note here recorded the **opposite** convention and was wrong despite a **[C]** marker. The multiply convention is confirmed by the 30JUN2026 rates: `KWD 4.2054`, `USD 1.2948`, and `BND 1.0000` (pegged 1:1 to SGD, which only reads correctly under multiply).

`ECL Manual Override` (§11.15) now also reads the monthly table, for the `LCY_LEDGER_BAL` conversion described below. **[C]**

**The table carries variant currency codes alongside the standard ones.** Seen at 30JUN2026: `CNO` and `CNH` beside `CNY`; `INO`/`INH` beside `INR`; `KRO`/`KRH` beside `KRW`; `TWO` beside `TWD`; and `IDO`/`IDH`, `MYO`, `PHO`/`PHH`, `THO`/`THH`, `VNO` beside their base codes. Some carry an identical rate to the base, some differ slightly — `CNH` is the recognised offshore renminbi code, so these look like onshore/offshore book splits. **[I]** on what `O` and `H` denote.

This matters wherever `CURCY_CODE` is used as a grouping or join key, because a variant and its base are treated as unrelated currencies: a benchmark population in `CNY` will not match an account in `CNO`, and a journal keyed on the code will post them as separate currency lines. Whether any account actually carries a variant code is **[O]** — a distinct-code count on the product files would settle it. `ECL Manual Override` prints every non-SGD account in its own population for the same reason, which settles the question for that population only.

**Ratings (`T_MTH_FRS9_AC_RATING_DTL`):** an account carries up to two rows per month, distinguished by `ORGL_CR_RATING_FLG` — `Y` = origination rating, `N` = current rating.

**`RDL_AC_DTL.GL_AC_ID` is segment 4 of the EGL account string — the product code.** It reproduces the `GL_CODE` field that all five product input tables carry **[I]**, so it is what the source system holds and not a derived value:

- **Loans and guarantees: `00000`.** 491,947 MSL and 3,743 MBS accounts on that one value in June 2026. This is the **posting convention, not a data defect** — ECL on a loan genuinely posts with `00000` in segment 4, so `EGL Posting Check` building the string from `GL_AC_ID` matches what HO posts. **[C]**
- **Investments: a real product code**, so RDL can be used to derive the segment-4-to-product mapping for investments (`57131` → `SG_REVRPO`, `58313` → the five bond products, and so on) but not for loans. **[C]**
- **NOSTRO, from Jul26: `00000`.** The §12 spec sets `INVMT_DTL.GL_CODE` to a literal `00000`, so NOSTRO is the first investment population on that value and "investments carry a real product code" no longer holds table-wide. **[C]**

**`RDL_AC_DTL.LCY_LEDGER_BAL` (`24.3`) is the only ledger balance on the table — there is no RCY twin.** The nearest RCY column is `RCY_CUR_PAR_BAL` (`24.3`), which sits immediately beside it at columns 35 and 36 but is a different concept: current par balance, not ledger balance. Whether the two are in fact an LCY/RCY pair is **[O]** — testable by checking they match for SGD accounts and that their ratio equals `EXCHG_RT` for the rest. Until that is settled, any process needing the ledger balance in account currency has to convert it: `ECL Manual Override` (§11.15) divides by `EXCHG_RT`. **[C]**

**`T_FRS_RT_INTF` — rate interface.** Not a `T_MTH_` table but still monthly by `PROC_DTE`. Several rows per account, each with an `RT_EFF_DTE` and a `PRM_RT_NO` peg code, so it needs deduping to the latest row before use. `PRM_RT_NO` **90 = 1-month SORA, 91 = 3-month SORA**; other codes exist (52 seen) and an account that has moved off SORA still carries its old 90 or 91 rows underneath the current one — so the peg filter must be applied **after** the dedupe, never in the read. `RT_EFF_DTE` can be **after** the reporting date: these are future-scheduled rates. **[C]**

**`T_MTH_FRS9_RT_DTL` — rate tiers.** One row per account per rate period, so a fixed-then-floating loan carries both its fixed tiers and its floating ones. `RT_EFF_DTE` and `RT_END_DTE` are **datetimes**, not dates — a date format applied to them overflows and renders as asterisks. `TIER_INT_RT` = `BASE_RT` + `VAR_RT`. **[C]**

**On a fixed-then-floating loan still inside its fixed period, `LN_DTL.BASE_RT` holds the SORA rate the account is pegged to, not the fixed rate it is currently charging.** `RT_TYP_DESC` reads `FIXED RATE` throughout. **[C]**

**`RDL_AC_DTL.SRC_PROD_TYPE_CD` is the `PRD_CODE`** carried through from the product files, so RDL rows can be tied back to a product without joining to the input tables. **[C]**

**`RDL_AC_DTL.LEGAL_ENTITY` uses the `CO_CODE` convention — `001` and `003`** — not the `MBB-SG` / `MSL` strings the five product input tables carry on `LEGAL_ENTITY_CODE`. This is the canonical record of which convention lands on which table; the four-way entity map itself is in `FRS9_Work_Reference.md` §2. It matters wherever RDL is joined or patched on entity: the `EIR Future Repricing Adjustment` patch file (§11.13) hardcodes `003` for MSL. **[C]**

**Market segment lives on both `RDL_AC_DTL` and `PARTY_MSTR`, and either is usable.** `RDL_AC_DTL` has `MKT_SEG`, `SUB_MKT_SEG` and `SUB_MKT_SEG_DESC` (all `$15`); `PARTY_MSTR` has `MKT_SEG_DESC`, `MKT_SUB_SEG` and `MKT_SUB_SEG_DESC` (`$60`). Note the description column names are **transposed** between the two (`SUB_MKT_SEG_DESC` against `MKT_SUB_SEG_DESC`), which is easy to misread as the column being absent. There is no truncation risk on the narrower pair. `ECL Flux` (§11.10) takes it from `PARTY_MSTR` because it is a borrower attribute, not because AC_DTL lacks it. **[C]** The **value domain of `MKT_SUB_SEG_DESC` is not recorded anywhere in this pack**, and it is not the same domain as `MKT_SUB_SEGMENT` on `RDL_MSTR_LIST`, whose six labels are in `LBFRS9_T_MTH_FRS9_RDL_MSTR_LIST__MKT_SUB_SEGMENT.txt`. §11.10 now filters on one of its values by literal, so the domain matters — `Open_Items.md` item 10. **[O]**

**The short-term flags `F_SHORT_TERM_IND` and `F_SHORT_TERM_INCEP_IND` (`$1`) are on `RDL_MSTR_LIST` only** — `RDL_AC_DTL` has no such columns. They form part of the EGL Mapping lookup key, so any process building that key needs `RDL_MSTR_LIST` and not just `RDL_AC_DTL`. **[C]** Three do: `EGL Posting Check` (§11.8), `Post-Posting TB Recon` (§11.9) and `ECL Manual Override` (§11.15). The flags are populated **only for Interbank Placement**, on both the mapping and RDL, so blank matches blank and a single exact-match lookup serves every product — no blank-flag retry is needed or used. **[C]**

`RDL_MSTR_LIST` also supplies `V_CUSTOMER_PARENT_GROUP_NAME` (`$30`) and `V_FINANCING_CODE` (`$1`), the interco and Islamic segments of the account string, which are likewise absent from `RDL_AC_DTL`. **[C]**

### EIR columns on RDL

`RDL_AC_DTL` carries four EIR amounts, of which **only the first is used** by any current process:

| Column | Format | Content |
|---|---|---|
| `LCY_EIR_ADJ_AMT` | 24.3 | the EIR adjustment **balance** — used by `EGL Posting Check` and `Post-Posting TB Recon` |
| `LCY_EIR_ADJ_OPENING_AMT` | 24.2 | opening balance |
| `LCY_EIR_ADJ_FY_AMT` | 24.2 | financial-year movement |
| `LCY_EIR_ADJ_FTM_AMT` | 24.2 | movement for the month |

**EIR is the exception to the `FY` convention below — it is a balance, not a year-to-date movement.** So the EIR posting is whole-balance-and-reverse rather than movement-based (posting mechanics: `MER_00` §7), and `LCY_EIR_ADJ_AMT` is the right field for both checks: balance meets balance against an accumulated trial-balance figure. The other three are **not** substitutes there. **[C]**

**`FY_AMT` and `FTM_AMT` are derived from `AMT`, not independently sourced.** When IT patches `LCY_EIR_ADJ_AMT`, the loader recomputes both automatically — so a patch file carries the balance alone and the movement columns follow. This is why the `EIR Future Repricing Adjustment` patch (§11.13) is a one-column file and is nonetheless complete. **[C]**

It also means `OPENING_AMT + FY_AMT = AMT` holds by construction, maintained downstream rather than by whoever sends the file. Note the identity can only be tested to **2dp**: `AMT` is `24.3` while the three movement columns are `24.2`. Whether `OPENING_AMT` is the 31 December balance or the prior month's is still **[O]**, and matters only for a hold spanning a year end.

**The same convention applies to ECL patches on the LCY side only.** Send `LCY_ECL_CLOSING_FY` and the LCY movement columns are derived. **[C]**

> **The RCY twins are not derived.** IT's loader does not recompute `RCY_ECL_CHARGE_FY`, `RCY_ECL_WRITEBACK_FY` or the `FTM` pair from a patched `RCY_ECL_CLOSING_FY`, so an RCY ECL patch has to carry them explicitly. `ECL Manual Override` (§11.15) sends a five-column RCY file for that reason, against a closing-only LCY file. **[C]** This asymmetry matters because `Post-Posting TB Recon` (§11.9) reconciles on the four RCY **component** columns and not on closing — an RCY patch carrying closing alone would leave that recon broken on every patched account. Whether the LCY derivation also reaches the `FTM` pair, and splits charge against writeback the same way, is **[O]** and worth confirming after a load, because `ECL Flux` (§11.10) reads the LCY `FTM` columns.

The differing decimal format suggests the three movement columns were added to the table later than `LCY_EIR_ADJ_AMT`. **[I]**

`RDL_MSTR_LIST` carries the engine-native equivalents `EIR`, `EIR_OPENING` and `EIR_PREVIOUS`. **`EIR_PREVIOUS` is the prior month's balance** — the amount HO's reversal file should carry, which would let `EGL Reversal Check` test the EIR leg against a stated figure rather than only against last month's posting. **[I]** — not yet used anywhere. It also carries `N_EIR_ADJUSTMENT_AMT_RCY` (`24.3`), a fourth EIR field of unknown relation to the other three. **[O]**

### Fair value columns on RDL

`RDL_AC_DTL` carries `RCY_FAIR_VALUE` and `LCY_FAIR_VALUE` (both `24.2`), with `SEC_CLS_CD = 'FVOCI'` marking the rows they apply to.

**The engine does not compute these — Singapore does, and patches them in.** The `FVOCI Loan MTM` process (§11.12, `MER_11_12_FVOCI_Loan_MTM.md`) marks the FVOCI loan book locally, posts the journal, and sends IT a patch file keyed on `UNIQUE_ID_NO` to load the figures onto RDL. Two things then depend on them being there: next month's reversal reads `RCY_FAIR_VALUE` back off RDL rather than recomputing, and `Post-Posting TB Recon` (§11.9) uses `RCY_FAIR_VALUE` as the expected FVOCI balance on the GL. That second dependency is also the **control**: a patch that never loads surfaces as an FVOCI break in §11.9 in the same cycle, not silently. **[C]**

### Opening-balance FX columns — not understood

`RDL_AC_DTL` carries `ECL_OPENING_REVAL_RCY`, `ECL_OPENING_FX_DIFF`,
`ECL_OPENING_FX_DIFF_FTM`, `UWI_OPENING_REVAL_RCY` and `UWI_OPENING_FX_DIFF`
(all `26.2`). No process reads them. Whether they are posted or informational
is **[O]** — relevant because `Post-Posting TB Recon` reconciles the opening GL
against `RCY_ECL_OPENING_BAL` alone and records that openings always differ at
account level.

### GL columns stated on RDL

`RDL_AC_DTL` carries `GL_ID_*` columns next to each amount, including
`GL_ID_EIR_ADJ_BS` and `GL_ID_EIR_ADJ_PL`. **None are used** — every process
takes the GL from the EGL Mapping instead. Comparing the two would
independently confirm the mapping. **[C]**

### Local schedule table — `EIR_ADJ_SCH`

Not an FRS9 table. A locally maintained SAS dataset held in two places: `BASE.EIR_ADJ_SCH` in `My SAS Files` is the **source of truth**, and `LBDSFAU.EIR_ADJ_SCH` is a full mirror overwritten each month. **[C]**

| Grain | One row = |
|---|---|
| `PROC_DTE` + `ACCOUNT_NUMBER` | one pool account, one month |

Columns: `PROC_DTE`, `ACCOUNT_NUMBER`, `BS`, `PL`, `ACCT_STATUS_CODE`, `BIZ_UNIT_CODE`, `SUB_ACCOUNT`.

Note the key column is `ACCOUNT_NUMBER`, not `AC_CODE` — it joins to `LN_DTL.AC_CODE`. It holds a **closed pool** of MSL accounts (the historical AEL catch-up), so it only ever shrinks; see §11.11 (`MER_11_11_EIR_AEL_Adjustment.md`) for what it is and how it is serviced. **[C]**

### Local schedule table — `FUT_REPRICING_<yymm>`

Not an FRS9 table. Locally maintained, in `FUTREP` = `My SAS Files\futrep`. **One dataset per month**, month tag from `PROC_DTE`, e.g. `FUT_REPRICING_2606`. Written by `EIR Future Repricing Adjustment` and read back the following month as the reversal; see §11.13 (`MER_11_13_EIR_Future_Repricing.md`). **[C]**

| Grain | One row = |
|---|---|
| `AC_CODE` (one month per dataset) | one future-tagged account, one month |

| Column | Type | Note |
|---|---|---|
| `PROC_DTE` | Num `DATETIME20.` | month end, **datetime** not date |
| `AC_CODE` | Char `$50` | joins to `RDL_AC_DTL.UNIQUE_ID_NO`, so suffixed |
| `PRD_CODE` | Char `$50` | one of the four housing-loan codes |
| `REPRICE_DATE` | Num `DATETIME20.` | later than `PROC_DTE` by construction |
| `BIZ_UNIT_CODE` | Char `$20` | becomes `COST_CENTRE` on the entry |
| `FINANCING_CODE` | Char `$1` | `C` / `I`; drives `SUB_ACCOUNT` |
| `CURR_MTH_EIR` | Num `24.3` | `LCY_EIR_ADJ_AMT` this month, missing coalesced to 0 |
| `PREV_MTH_EIR` | Num `24.3` | prior month, the figure the RDL patch holds at |
| `EIR_DIFF` | Num `24.3` | current less prior; rows rounding to zero are excluded |

Contrast `EIR_ADJ_SCH` above, which is a **single accumulating table** keyed on `PROC_DTE` and held in two places. This one is month-per-dataset with no mirror, which is what makes the write idempotent — a rerun overwrites only its own month. **[C]**

The oldest month (migrated from Excel) carries narrower character widths than the `LN_DTL`-native months (`AC_CODE` `$11`, `PRD_CODE` `$8`, `BIZ_UNIT_CODE` `$5`). Nothing appends months together, so this is harmless — but it would bite anyone who stacked the datasets. **[C]**

Note `LN_DTL` also carries `REPRICE_FLAG` (`$1`) beside `REPRICE_DATE`. The
process selects on the date alone; whether the flag is redundant is **[O]**.

### Master listing extract — `MTH.MASTERLISTING_<yymm>`

Not an FRS9 table. A local per-month copy of the master listing HO returns,
held in the month output folder. It exists as a **fallback source** for the four
`RDL_MSTR_LIST` fields the account string and the EGL Mapping key need, used by
`EGL Posting Check`, `Post-Posting TB Recon` and `ECL Manual Override` when
`RDL_MSTR_LIST` has not yet loaded for the month. It holds one month only, so it
needs no date filter. Column names match `RDL_MSTR_LIST`. **[C]**

### Product hierarchy master (`T_FRS9_PRD_MSTR`)

Keyed on `PRODUCT_HIERARCHY_CD`, joined from the product-code field of each consuming table:

| Consuming table | Join field → `PRODUCT_HIERARCHY_CD` |
|---|---|
| 5 product input tables (`LN_DTL`, `CC_DTL`, `OD_DTL`, `INVMT_DTL`, `GUARANTEE_DTL`) | `PRD_CODE` |
| `RDL_AC_DTL` | `SRC_PROD_TYPE_CD` |
| `RDL_MSTR_LIST` | `V_PROD_CODE` |

`SG_NOSTRO` maps to `LEVEL_3 = Cash and STF`. **[C]** Note the EGL Mapping
lookup joins from `SRC_PROD_TYPE_CD`, not `PRD_CODE` — so a NOSTRO row only
resolves if the engine carries `SG_NOSTRO` through to `RDL_AC_DTL`.

### Securities classification (`SEC_CLS_CD`)

`SEC_CLS_CD` (`$20`) exists on `RDL_AC_DTL` only. The product input tables
carry `IFRS9_CLASS_CODE` instead, and the engine derives one from the other —
so a spec that needs `AMRTCOST` or `FVOCI` on RDL sets `IFRS9_CLASS_CODE` on
the input. This is how the NOSTRO spec (§12 field 17) populates it. **[C]**

---

## 2. Structural facts about RDL

- **RDL accumulates through the year.** An account closed in an earlier month
  still appears in every later month's RDL. The five product files are the
  opposite — point-in-time, so a closed account appears in the month it closed
  and not after. **[C]** This is why the ECL Flux filter on non-zero
  current-month P&L matters: by mid-year most RDL rows are dormant. It is also
  why any process taking every row under a customer will pick up long-closed
  accounts sitting at nil balance — `ECL Manual Override` (§11.15) releases any
  residual provision on those.
- **`FY` is year-to-date, `FTM` is the month.** ECL and UWI postings use `FY`;
  the flux analysis uses `FTM`. EIR is the exception — see the EIR section
  above.
- **RCY and LCY have different sign conventions.** `LCY_ECL_WRITEBACK_FTM` is
  already negative; `RCY_ECL_WRITEBACK_FTM` is positive. Swapping one column
  for its twin without changing the arithmetic silently doubles the figure.
  **[C]** So on the RCY side all four ECL components are positive magnitudes,
  and any hand-built RCY patch must respect that.
- **The component identity, and where it is now tested.** In RCY terms, with all
  four components positive, it reads
  `CLOSING = OPENING + CHARGE − WRITEBACK − WRITEOFF`. `ECL Manual Override`
  (§11.15) computes it as a check column on the accounts it touches and expects
  nil, and derives the required year movement from it as
  `target − opening + write-off`. Every other process still checks RDL only
  against HO's file or against the ledger, so whether the identity holds across
  the table as a whole remains **[O]**.
- **A month's absence from a `T_MTH_` table cannot be probed with `OBS=`.** A
  `datepart(PROC_DTE)` filter does not push down to Oracle, so the engine
  applies the row limit and SAS applies the filter afterwards — `obs=1` tests
  one arbitrary physical row, and RDL holds every month of the year. Count over
  a datetime range on the raw column instead. **[C]**
- **The cost of that non-pushdown: 4×–14× elapsed** (measured Aug26, identical
  rows out on every pair tested). The shape of the step does not matter —
  `SET`, `PROC SORT` and `PROC SQL` all gained, including `PROC SQL` steps
  joining an Oracle table to a WORK table. The gap widens by one month's rows
  every cycle. The log states which happened: fast runs print the literals in
  the `WHERE` sent to Oracle, slow ones print `DATEPART(PROC_DTE)=24318`. **[C]**

- **Which tables retain months.** `RDL_MSTR_LIST`, `RDL_AC_DTL`, the five
  product tables, `T_FRS_RT_INTF`, `RT_DTL` and `LBDWH.T_DAL_CURCY_EXCHG` all
  do — every one showed the multiple above. Note this is separate from the
  point-in-time property of the product files, which is about **account**
  presence within a month, not about how many months the table holds. **[C]**
- **Standing rule: filter `PROC_DTE` with bounded datetime literals.** Applies
  to every `LBFRS9` and `LBDWH` table. The bounded form (`>= month end` and
  `< next day`) rather than equality on the literal, so a non-midnight timestamp
  cannot be missed. The convention itself is in the sas-writing skill; the
  figures above are why. Rollout status is `Open_Items.md` item 13. **[C]**

  Two `datepart()` uses are **not** covered by the rule and should stay:
  a filter on a WORK table, which has no database to push to (§11.12 line 132,
  the WAIR window), and `datepart()` used as a conversion in an assignment
  rather than a filter (§11.5, §11.12). **[C]**
