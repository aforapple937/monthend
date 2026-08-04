# Month-End Cycle and Posting (MER_00)

Shared machinery for the monthly IFRS 9 ECL / EIR reporting cycle: the
sequence, the EGL mapping, what HO returns, the EGL account string, and how
ECL / EIR / FVOCI are posted. One file per stored process sits alongside as
`MER_11_01`…`MER_11_16`; the NOSTRO spec is `MER_12_NOSTRO_Enhancement.md`.
Index and file map: `FRS9_Work_Reference.md`. Section numbers §1–§10 are kept
from the former `Month_End_Reporting.md`, so older references still resolve.

Status markers: **[C]** confirmed, **[I]** inferred, **[O]** open.

---

## 1. The monthly cycle

    Singapore local IT batch
        -> generates LBFRS9 files from DWH
            -> sent to Head Office (Malaysia)
                -> HO calculates ECL and EIR adjustment

Singapore IT triggers the batch that builds the LBFRS9 files out of the data
warehouse. Those files go to HO in Malaysia, and HO runs both the ECL and the
EIR adjustment computation off them. **[C]**

Implications not yet confirmed:
- `RDL_MSTR_LIST` and `RDL_AC_DTL` are therefore engine *output* returning to
  Singapore, not something local IT produces. **[I]**
- The finance team's own work sits either side of that handover — assuring the
  files before they go, and reviewing/reconciling/explaining what comes back.
  Which side dominates the month is unknown. **[O]**
- Whether ECL and EIR are one submission or two separate cycles with separate
  deadlines. **[O]**

#### Month-end sequence, as established so far

| # | Step | Purpose | Stored process |
|---|---|---|---|
| 1 | Pre-Check TB | Confirm no one else has posted into the ECL/EIR GLs | `Pre-Check TB` |
| 2 | Balance Recon | Confirm the five product files are complete before sending to HO — summary and by-product detail | `Balance Recon` |
| 3 | Currency Change Check | Identify accounts whose currency changed, for HO to patch the opening ECL | `Currency Change Check` |
| 4 | Input File Validation | Column-level checks on the product files — **in build** | *(name TBC)* |
| 5 | SORA Rate Patch | Refresh the SORA rate on fixed-then-floating loans still inside the fixed period; two patch files go to IT | `SORA Rate Patch` |
| 6 | SORA Patch Verification | Confirm IT applied them | `SORA Patch Verification` |
| — | *files sent to HO; HO runs the month-end batch* | | |
| 7 | EIR AEL Adjustment | Roll the AEL catch-up pool forward, release closed accounts to P&L, build the GL entry — runs while waiting for HO | `EIR AEL Adjustment` |
| 8 | FVOCI Loan MTM | Mark FVOCI loans to model, build the OCI journal and the RDL patch file — also runs while waiting for HO | `FVOCI Loan MTM` |
| 9 | EGL Reversal Check | This month's reversal is the exact opposite of last month's posting | `EGL Reversal Check` |
| 10 | EGL Posting Check | HO's posting file agrees with RDL | `EGL Posting Check` |
| 10a | EIR Future Repricing Adjustment | Hold the EIR balance on accounts tagged for a repricing that has not taken effect; GL entry plus an RDL patch file for IT | `EIR Future Repricing Adjustment` |
| 10b | Overlay Watchlist | Stage, rating, EAD and ECL for the borrowers an overlay was provided against, current month against prior — printed report only, nothing persisted | `Overlay Watchlist` |
| 10c | ECL Manual Override | Force ECL to the full ledger balance for a named list of CIFs; GL entry plus LCY and RCY patch files for IT | `ECL Manual Override` |
| — | *IT applies the RDL patch files* | | |
| 10d | RDL Patch Verification | Read every patch file back off `My SAS Files\patch` and confirm RDL now holds what was asked for | `RDL Patch Verification` |
| — | *files processed by EGL* | | |
| 11 | Post-Posting TB Recon | The ledger itself agrees with RDL (BS only) | `Post-Posting TB Recon` |
| 12 | ECL Flux | Which borrowers drove the month's ECL P&L movement | `ECL Flux` |

Steps 1 and 2 both run **before** the files go to HO, and both read the same
two trial balance files from `PRETB`. **[C]**

**Input File Validation** (§11.4) is still in build — column-level quality
checks on the product input files before they go to HO. Its exact slot in the
sequence is not yet fixed; it logically sits alongside steps 1–3, pre-HO. **[I]**

Steps 7 and 8 are the only steps that neither prepare files for HO nor check
what came back — both are the team's own journals, run in the gap while HO's
batch is running. Detail in §11.11 and §11.12.

**Step 10a** is a third own journal, but it cannot run in that gap: it reads
RDL for two months, so it has to wait until HO's output is back. It sits after
`EGL Posting Check` and must complete **before** IT patches RDL — see §11.13.

**Step 10b** is neither a journal nor a check — it is a monitoring read over
RDL for a named list of borrowers, run after 10a. It posts nothing and patches
nothing, so its only constraint is that RDL is back; nothing downstream depends
on it. See §11.14.

**Step 10d** closes the loop on the three processes that send patch files to IT
— `FVOCI Loan MTM` (§11.12), `EIR Future Repricing Adjustment` (§11.13) and
`ECL Manual Override` (§11.15). It is file-driven rather than process-driven:
it verifies whatever sits in `My SAS Files\patch`, so it covers all three in one
run and covers a fourth without being changed. Its only hard constraint is that
it runs after IT's load; running it before §11.9 is the useful placement,
because that recon takes patched RDL as its expected side and a patch that never
loaded would otherwise surface there as a ledger break with no obvious cause.
**[I]** See §11.16.

---

## 2. Four processes share one GL population

The EGL Mapping file covers four related processes that post to an overlapping
set of general ledger accounts:

- **ECL** — expected credit loss provision
- **UWI** — unwinding of interest **[I]**; present only for Loans And Advances,
  which is consistent with Stage 3 unwinding
- **EIR** — effective interest rate adjustment
- **FVOCI** — fair value through OCI

---

## 3. Trial balance files — practical notes

Canonical home for these facts. Applies to every step that reads a trial
balance export: `Pre-Check TB` (§11.1) and `Balance Recon` (§11.2) on `PRETB`,
`Post-Posting TB Recon` (§11.9) on `posttb` — same exports, same behaviour.

- **The two exports use different delimiters.** MBS comes out **tab**-delimited,
  MSL **comma**-delimited. The MSL file also contains blank lines. Discovered
  the hard way: `DSD` alone made every MBS line fail to parse, which surfaced
  as "found 1 entity" rather than as a parsing error. Both scripts now detect
  the delimiter per line and stop if they find neither. **[C]**
- **File names carry no meaning.** Entity is read off segment 1 of `ACCOUNTS`,
  so the wildcard reads whatever is in `PRETB`. Keep that folder to the two TB
  files only.
- Files are dragged manually into `PRETB` and the folder is cleared each month.

---

## 4. EGL Mapping file structure

Beyond its use as a GL list for the pre-check, this file is the **posting map**:
given an exposure's characteristics, it gives the GL for each leg of the entry.

**Key columns:** `LEVEL_3`, `F_SHORT_TERM_IND`, `F_SHORT_TERM_INCEP_IND`,
`SEC_CLS_CD` — followed by the 18 GL columns.

`LEVEL_3` ties back to `LBFRS9.T_FRS9_PRD_MSTR` (product hierarchy), which is
also used in the `V_IFRS_STAGE_CODE` derivation. **[I]**

Full file, 10 rows:

| LEVEL_3 | ST | ST_INCEP | SEC_CLS_CD |
|---|---|---|---|
| Interbank Placement | Y | Y | AMRTCOST |
| Interbank Placement | N | N | AMRTCOST |
| Interbank Placement | Y | N | AMRTCOST |
| Investments | | | AMRTCOST |
| Investments | | | FVOCI |
| Loans And Advances | | | AMRTCOST |
| Loans And Advances | | | FVOCI |
| Off Balance Sheet | | | AMRTCOST |
| Off Balance Sheet | | | FVOCI |
| Rev Repo | | | AMRTCOST |

Structural observations:

- **UWI populated only for Loans And Advances** (both AMRTCOST and FVOCI); blank
  for every other `LEVEL_3`.
- **EIR and FVOCI columns are product-agnostic** — `EIR_BS 1207001`,
  `EIR_PNL 7101701`, `FVOCI_BS 1220001`, `FVOCI_OCI 4121514` on every row. Only
  ECL and UWI vary by product.
- **Short-term flags are used only by Interbank Placement**, which splits three
  ways (Y/Y, N/N, Y/N). The Y/N row is a hybrid: opening and writeback from the
  N/N set, charge and writeoff from the Y/Y set.
- **UWI charge and writeback share a GL** — `1207004` on the BS side, `5251002`
  on the P&L side. They net rather than sitting in separate accounts.
- **Off Balance Sheet write-off points at the on-BS loan write-off GL** —
  OBS AMRTCOST `ECL_WRITEOFF` = `3403104` (same as Loans And Advances
  AMRTCOST), OBS FVOCI = `4121704` (same as Loans And Advances FVOCI), while
  every other OBS column has its own `3453xxx` / `4121705-707` account.
  **Confirmed correct, not an error.** **[C]**

Across the 10 rows, the 16 in-scope columns yield **60 distinct GL numbers**
(61 including `6701015` from the two excluded columns).

---

### 4.1 EGL mapping load (`egl_map_load.sas`)

One-time script, re-run only when the mapping changes; the monthly code and
outputs are documented in §11.1.

- **Mapping stored as CSV read by an explicit DATA step, not `PROC IMPORT` of
  xlsx.** Importing xlsx makes the GL columns numeric, which loses any leading
  zero and breaks the comparison against a character `scan()` result. All GL
  columns are `$7`.
- The in-scope list is derived from the stored mapping at run time (`$INSCOPE`
  format via `CNTLIN`); nothing is hardcoded, so reloading the mapping is the
  only step needed when GLs change.

---

## 5. What comes back from HO

HO returns two things. **[C]**

**RDL and MASTERLISTING** — `T_MTH_FRS9_RDL_AC_DTL` and
`T_MTH_FRS9_RDL_MSTR_LIST`, the engine output, landing in `LBFRS9`.

**Four CSV files sent directly to EGL** — a posting and a reversal per entity.
They arrive in `My SAS Files\eglfile`, which holds six at a time because the
prior month's postings stay for the reversal comparison.

---

## 5.1 EGL posting file layout

Pipe-delimited despite the `.csv` extension, values quoted, first line a `"BH"`
control record.

File name: chars 1–3 entity, chars 10–11 the code where **`11` means reversal**
and anything else is a posting, chars 12–17 the month-end date as `DDMMYY`.
The posting code is not reliably `01`, so postings are identified by exclusion.
**[C]**

| Field | Meaning |
|---|---|
| 4 | D / C |
| 6–13 | eight segments of the account string |
| 21 | reporting date |
| 22 | amount |
| 23 | currency |
| 28 | description, e.g. `0626 ECL CHARGED` — embeds the month |

---

## 6. The EGL account string

Eight dash-separated segments, the same shape as `ACCOUNTS` on the trial
balance. **[C]**

| Seg | Meaning | Built from |
|---|---|---|
| 1 | Entity — `128` MBS, `252` MSL | `LEGAL_ENTITY` `001`→`128`, `003`→`252` |
| 2 | RC (responsibility centre) | `AC_MGR_UNIT_CODE` |
| 3 | GL number | EGL Mapping |
| 4 | Product code | `GL_AC_ID` |
| 5 | Interco code | `V_CUSTOMER_PARENT_GROUP_NAME`, else `000` |
| 6 | dummy | `00000` |
| 7 | Islamic indicator — `8999` Islamic | `8999` if `V_FINANCING_CODE = "I"` |
| 8 | dummy | `0000` |

`ACC_PROD` on the trial balance is segments 3 + 4 concatenated, which is the
form `TB_MAPPING` keys on.

**The Islamic indicator matters for keys.** The same GL and product can appear
twice, once conventional and once Islamic, so anything joining postings to the
TB must use the full string rather than GL + product.

**Test segment 7 for `8999` exactly.** It is not a two-value flag: the trial
balance also carries `9993` (seen on `1203001-13221`) and `9996` (on the card
accounts `16111` and `16121`), neither of which is Islamic. A test of "not
`0000`" would misclassify them. Whatever those two mark, it cuts across the
Islamic split rather than being an alternative to it. **[C]**

**FVOCI is the exception**: RC is always `82101` and everything after the GL is
`-00000-000-00000-0000-0000`. **[C]**

Entity codes across the four conventions: the canonical map is
`FRS9_Work_Reference.md` §2 — not restated here.

---

## 7. How ECL and EIR are posted

Year-to-date movement: post the current YTD, reverse the prior month's YTD.
**[C]**

`LEVEL_3` for the mapping lookup comes from `T_FRS9_PRD_MSTR` joined on
`SRC_PROD_TYPE_CD = PRODUCT_HIERARCHY_CD`, with two overrides applied in order:
Bank Guarantee / Letter Of Credit / Shipping Guarantee → `Off Balance Sheet`;
then `SG_REVRPO` / `SG_ISLMREVRPO` → `Rev Repo`. **[C]**

Seven posted components, all `FY`:

| Component | Amount | Dr | Cr |
|---|---|---|---|
| ECL charge | `RCY_ECL_CHARGE_FY` | ECL_PNL_CHARGE | ECL_CHARGE |
| ECL writeback | `RCY_ECL_WRITEBACK_FY` | ECL_WRITEBACK | ECL_PNL_WRITEBACK |
| ECL write-off | `RCY_ECL_WRITE_OFF_FY` | ECL_WRITEOFF | ECL_PNL_WRITEOFF |
| UWI ×3 | `RCY_INT_UNWIND_*_FY` | as above | as above |
| EIR | `LCY_EIR_ADJ_AMT` | EIR_BS | EIR_PNL |

**ECL and UWI post in the account's own currency; EIR posts in SGD.** That is
also why the currency-change patch is needed at all — EIR, being SGD
throughout, has no equivalent problem. **[C]**

#### Two different posting bases

ECL and UWI amounts are `_FY` fields — **financial-year movement**, which resets
each January. EIR is not: `LCY_EIR_ADJ_AMT` is a **balance**. So the EIR entry
posts the entire current balance and reverses the entire prior-month balance,
while ECL and UWI post the YTD movement and reverse the prior YTD movement.
**[C]**

Both mechanisms leave the GL carrying the right closing figure; the difference
matters only when comparing a GL against RDL, which is why §11.9 handles the two
groups differently.

The EIR AEL Adjustment (§11.11) posts on the **same whole-balance basis** as
HO's EIR — post the whole pool, reverse the whole prior pool.

**FVOCI is not posted by HO — it is posted by Singapore.** The two FVOCI GLs
are written monthly by the FVOCI Loan MTM process (§11.12): reverse the whole
prior mark, post the whole current one, on the same **whole-balance** basis as
EIR. Nothing in HO's own posting file touches them, which is why they remain
the team's alone and stay in scope for the pre-check. **[C]**

> Corrects an earlier note here that nothing in the monthly cycle wrote to the
> FVOCI GLs at all. It is HO that does not write to them.

#### The January transfer — what populates the opening GLs

`ECL_OPENING` / `UWI_OPENING` are not written by the monthly cycle. They are
written **once a year**: every January the balances sitting on the charge,
writeback and write-off BS GLs are transferred out into the matching opening GL.
**[C]**

That is what keeps the ledger tying to RDL. The `_FY` fields reset in January,
so without the sweep the charge GL would carry last year's accumulated charge
against a `RCY_ECL_CHARGE_FY` that had gone back to zero. After the sweep each
GL holds exactly its RDL counterpart — the opening GL the opening balance, the
charge GL the current-year charge. It is a real journal, not a presentational
adjustment, and it is the reason `ECL opening` and `UWI opening` exist as
components in §11.9.

**EIR has no such split** — one BS GL, no opening GL, no January transfer.
Its accumulated GL balance is simply the whole EIR balance, which is what
`LCY_EIR_ADJ_AMT` already is.

The transfer posts into GLs that are in scope for Pre-Check TB, so January runs
a different control — see §11.1.

---

## 8. Why the P&L cannot be reconciled

EGL translates a P&L posting to SGD when it books it and never revalues it. The
balance sheet is revalued to closing rate every month. So the reversal of last
month's posting returns at a different rate from the original, and the FX
residue is absorbed on the BS by revaluation but accumulates on the P&L in SGD,
with nothing in RDL to match against. **[C]**

Observed on `REV REPO`, Jan to Feb: BS `YTD_NET_ENTERED` held at (9,617,677)
JPY and (124,961) USD while `YTD_NET_ACCOUNTED` moved from (79,232) to (77,931)
and (158,288) to (158,013) — the 1,301 and 275 being that month's revaluation.
The P&L had by then collapsed to one SGD row of 237,520 with ENTERED =
ACCOUNTED. The 237,520 against (235,945) gap is exactly 1,301 + 275.

Hence the post-posting recon is **balance sheet only**, on `YTD_NET_ENTERED`
against `RCY_` amounts — both in original currency, both immune to revaluation.

---

## 9. Folder layout

| Folder | Contents | Cadence |
|---|---|---|
| `My SAS Files` | `egl_mapping`, `tb_mapping` and other static tables; `EIR_ADJ_SCH` | as needed |
| `My SAS Files\PRETB` | pre-posting trial balances | cleared monthly |
| `My SAS Files\patch` | the patch files **as sent to IT**, csv or Excel — read back by `RDL Patch Verification` (§11.16) | cleared monthly |
| `My SAS Files\posttb` | post-processing trial balances | cleared monthly |
| `My SAS Files\fifo` | `FIFO_SGSG<yyyymmdd>.xlsx` | monthly |
| `My SAS Files\eglfile` | six EGL CSVs | rolling |
| `My SAS Files\futrep` | `FUT_REPRICING_<yymm>` future repricing schedules | monthly, retained |
| `My SAS Files\<yymm>` | all outputs | created by `dlcreatedir` |
| `My SAS Files\<yymm>\glte` | GL upload templates — `EIR_AEL_ENTRIES`, `FVOCI_MTM_ENTRIES`, `FUT_REPRICING_ENTRIES`, `ECL_OVERRIDE_ENTRIES` | monthly |

The month folder still holds everything else, including the SAS patch tables
the producing scripts write (`OUT.FRS9_EIR`, `MTH.MTH_FVOCI_MTM`,
`MTH.FRS9_CLOSING_BAL`, `MTH.RCY_TO_PATCH`). `patch` is the other half of that
handoff — the hand-exported csv or Excel copies that actually went to IT, kept
so they can be read back and verified. Like `PRETB` it holds one month at a
time and must be cleared, because §11.16 keys on the account alone and would
happily verify a stale file against the current month.

---

## 10. Script environment notes

Generic SAS traps (INTO: rounding, PROC IMPORT typing, SHEET=/RANGE=,
wildcard FIRSTOBS, and the rest) live in the **sas-writing skill**. Two
project-specific points stay here:

- **`LIBNAME LBFRS9` is not in any of these scripts** — it must be added before
  the product-file steps will run. Path or connection details unknown. **[O]**
- **Pack convention:** every exception check prints an explicit "no exceptions"
  line or stops with an error — the standing exception to the skill's
  no-printing rule, for the reason the skill records (an empty table reads the
  same as a clean result).

---
