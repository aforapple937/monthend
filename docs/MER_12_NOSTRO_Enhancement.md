# 12. NOSTRO ECL enhancement

The NOSTRO ECL enhancement spec (formerly `Month_End_Reporting.md` §12).
Delivery status and open verification points: `Open_Items.md` item 3.
Index: `FRS9_Work_Reference.md`. Markers: **[C]** / **[I]** / **[O]**.

**Implementation date:** July 2026

### 1. Purpose

NOSTRO accounts exist in no account-level product system. They are carried only in the
general ledger, so they have never reached the FRS9 files sent to Head Office, and ECL on
NOSTRO has been computed manually outside the FRS9 process.

This enhancement brings NOSTRO into the FRS9 files so that HO calculates its ECL alongside
every other exposure, retiring the manual workaround. NOSTRO GL balances are pulled from the
GL system and turned into synthetic account-level rows, each treated as an investment-type
exposure to the correspondent bank that holds it.

The GL system has migrated from Computron to EGL. The DWH table still stores the GL number in
Computron format — there is no EGL account number in either `T_NOSTRO_CIF_MSTR` or
`T_MTH_GLBAL`; `GL_AC_CODE` in both is the Computron GL number.

---

### 2. Tables Affected

| Table | Library | Action | Grain of new rows |
|---|---|---|---|
| `T_MTH_FRS9_INVMT_DTL` | `LBFRS9` | Append | One row per NOSTRO GL × CO_CODE |
| `T_MTH_FRS9_AC_RATING_DTL` | `LBFRS9` | Append | One row per NOSTRO GL × CO_CODE |
| `T_MTH_FRS9_PARTY_MSTR` | `LBFRS9` | Populate for NOSTRO CIFs | One row per distinct NOSTRO CIF not already present as a party |

---

### 3. Source Tables

| Table | Library | Role | Key fields used |
|---|---|---|---|
| `T_NOSTRO_CIF_MSTR` | `LBFRS9` | Driver — which GLs are NOSTRO and whose they are | `GL_AC_CODE`, `ID_CODE`, `CIF_NO` |
| `T_MTH_GLBAL` | `LBDWH` | Current-month GL balances, sourced from EGL | `GL_AC_CODE`, `CO_CODE`, `LCY_AGR_BAL` |
| `T_BIC_LIST_MGIL` | `LBDWH` | SWIFT/BIC → group CIF translation | `INDV_SWIFT_CODE`, `GCIF_MGIL` |
| `T_DAL_CRRS_RDL` | `LBDWH` | Credit rating system output | `HDR_GCIF`, `HDR_RTD_DT`, `RDMS_ADJ_BRR`, `SEQUENCE_NO`, `SC_CODE` |
| `V_T_CIF_MSTR` | `LBDWH` | Customer name and country | `CIF_NO`, `CIF_NAME`, `CTZ_CODE`, `CNTRY_CODE` |
| `T_EGL_INTERCO_MAP_MSTR` | TBC | Intercompany group mapping | `CIF_NO`, `EGL_INTERCO_CODE` |

---

### 4. Building Table 1

Table 1 is the intermediate result that feeds all three target tables. It is built in four
steps.

### Step 1 — Identify NOSTRO GL listings

Left join `T_NOSTRO_CIF_MSTR.GL_AC_CODE` to the **current month** `T_MTH_GLBAL.GL_AC_CODE`
to pick up `CO_CODE` and `LCY_AGR_BAL`.

Then aggregate:

```
SUM(LCY_AGR_BAL) GROUP BY GL_CODE, ID_CODE, CIF_NO, CO_CODE
```

The `GROUP BY` makes `CO_CODE` part of the grain: a single NOSTRO GL can split across two
legal entities, and each split becomes its own FRS9 account.

Resulting columns: `GL_CODE`, `ID_CODE`, `CIF_NO`, `CO_CODE`, `SUM_of_LCY_AGR_BAL`.

### Steps 2–4 — Attach a credit rating for the correspondent bank

The counterparty is identified by SWIFT code, but the rating system is keyed on group CIF, so
a translation hop is required before the rating can be retrieved.

**Step 2 — Find GCIF_MGIL.** Left join `Table 1.ID_CODE` to current-month
`T_BIC_LIST_MGIL.INDV_SWIFT_CODE` to get `GCIF_MGIL`.

**Step 3 — Extract first-instance record from `T_DAL_CRRS_RDL`.** From the current month,
sort by:

1. `HDR_GCIF` ascending
2. `HDR_RTD_DT` descending
3. `RDMS_ADJ_BRR` descending
4. `SEQUENCE_NO` descending

Keep the first record per `HDR_GCIF` — the most recent rating review, breaking ties on the
worst BRR and then the latest sequence. Extract `RDMS_ADJ_BRR` and `SC_CODE`, and derive:

```
IF RDMS_ADJ_BRR = 'NA'  THEN Rating = 'RNA'
ELSE                         Rating = 'R' || RDMS_ADJ_BRR
```

**Step 4 — Derive Rating and SC_CODE for NOSTRO GL.** Left join `Table 1.GCIF_MGIL` to the
Step 3 result to attach `Rating` and `SC_CODE`.

### Table 1 final shape

One row per (GL_CODE, CO_CODE):

| Column | Origin |
|---|---|
| `GL_CODE` | NOSTRO master |
| `ID_CODE` | NOSTRO master (BIC) |
| `CIF_NO` | NOSTRO master |
| `CO_CODE` | GL balance table |
| `SUM_of_LCY_AGR_BAL` | Aggregated GL balance |
| `GCIF_MGIL` | BIC list |
| `Rating` | CRRS, derived |
| `SC_CODE` | CRRS |

---

### 5. Field Mapping — `T_MTH_FRS9_INVMT_DTL`

Append Table 1. No change to existing field formats. Every field not named below
is set to NULL.

| SN | Field | Logic |
|---|---|---|
| 1 | `GL_CODE` | `00000` (literal) |
| 2 | `PROC_DTE` | Month end date |
| 3 | `GAAP_CODE` | NULL |
| 4 | `PRD_CODE` | `SG_NOSTRO` |
| 5 | `AC_CODE` | `GL_CODE` + `CO_CODE`, e.g. `111410` + `001` = `111410001` |
| 6 | `BIZ_UNIT_CODE` | `22121` |
| 7 | `CURCY_CODE` | `SGD` |
| 8 | `CIF_NO` | NOSTRO master `CIF_NO` |
| 9 | `DATA_ORIGIN` | `SGDWH` |
| 10 | `LEGAL_ENTITY_CODE` | Existing logic: `CO_CODE` = `001` → `MBB-SG`; `CO_CODE` = `003` → `MSL` |
| 11 | `ORIGINAL_ACCOUNT_NUMBER` | Same as `AC_CODE` |
| 12 | `LOAD_RUN_ID` | `0` |
| 13 | `RCY_FACE_VAL_AMT` | `Table 1.SUM_of_LCY_AGR_BAL` |
| 14 | `LEDGER_BALANCE_AMT` | Same as SN13 |
| 15 | `CMA_FLAG` | `N` |
| 16 | `CREDIT_SCORE_SOURCE` | `Table 1.SC_CODE` |
| 17 | `IFRS9_CLASS_CODE` | `AMRTCOST` |
| 18 | `QUALIFYING_INS_FLAG` | `N` |
| 19 | `ACCT_STATUS_CODE` | `Active` |
| 20 | `FINANCING_CODE` | `C` |

---

### 6. Field Mapping — `T_MTH_FRS9_AC_RATING_DTL`

Append Table 1. No change to existing field formats. Every field not named below
is set to NULL.

| SN | Field | Logic |
|---|---|---|
| 1 | `RATING_SOURCE` | `ZMB_BANK_L` |
| 2 | `RATING` | `Table 1.Rating` |
| 3 | `AC_CODE` | `GL_CODE` + `CO_CODE`, e.g. `115108` + `003` = `115108003` |
| 4 | `ORGL_CR_RATING_FLG` | `N` |
| 5 | `PROC_DTE` | Month end date |
| 6 | `DATA_ORIGIN` | `SGDWH` |
| 7 | `EXTERNAL_RATING_SOURCE` | NULL |
| 8 | `EXTERNAL_RATING` | NULL |
| 9 | `INTERNAL_RATING_SOURCE` | `ZMB_BANK_L` |
| 10 | `INTERNAL_RATING` | `Table 1.Rating` |
| 11 | `LEGAL_ENTITY_CODE` | Existing logic: `CO_CODE` = `001` → `MBB-SG`; `CO_CODE` = `003` → `MSL` |

---

### 7. Field Mapping — `T_MTH_FRS9_PARTY_MSTR`

Populate for NOSTRO CIFs only. No change to existing field formats. Every field not
named below is set to NULL.

A row is added only where the NOSTRO `CIF_NO` does not already exist as a party. Where the
CIF is already present, the existing party row is left untouched and no NOSTRO row is added.

| SN | Field | Logic |
|---|---|---|
| 1 | `CIF_NAME` | Left join NOSTRO `CIF_NO` → `V_T_CIF_MSTR.CIF_NO`, take `CIF_NAME` |
| 2 | `DATA_ORIGIN` | `SGDWH` |
| 3 | `CIF_NO` | NOSTRO `CIF_NO` from `T_MTH_FRS9_INVMT_DTL` |
| 4 | `PROC_DTE` | Month end date |
| 5 | `INDUSTRY_CODE` | `8000` |
| 6 | `PARENT_GROUP_NAME` | Existing logic (see below) |
| 7 | `PARTY_BNKRPT_FLG` | `N` |
| 8 | `PARTY_TYP_CODE` | `BANK` |
| 9 | `CNTRY_CODE` | `V_T_CIF_MSTR.CTZ_CODE` |
| 10 | `PARTY_CLASS_CODE` | `BANK` |
| 11 | `MKT_SUB_SEG` | `16` |
| 12 | `CUST_MKT_SUB_SEG_DESC` | Blank |
| 13 | `MKT_SUB_SEG_DESC` | `GWB-GM` |
| 14 | `CUST_MKT_SUB_SUB_SEG_DESC` | Blank |
| 15 | `MKT_SEG_DESC` | `Global Banking` |
| 16 | `SECTOR_CAT` | `05` |
| 17 | `RATING_OUTLOOK_WATCH` | `N` |
| 18 | `SM_FLG` | `N` |
| 19 | `CNTRY_OPERATION` | `V_T_CIF_MSTR.CNTRY_CODE` |
| 20 | `NAICS_CODE` | `0801404002` |

### `PARENT_GROUP_NAME`

Existing logic, reused unchanged:

```
Left join T_MTH_FRS9_PARTY_MSTR.CIF_NO
       → T_EGL_INTERCO_MAP_MSTR.CIF_NO
  to get EGL_INTERCO_CODE

IF EGL_INTERCO_CODE is not missing THEN PARENT_GROUP_NAME = EGL_INTERCO_CODE
ELSE                                    PARENT_GROUP_NAME = '000'
```
