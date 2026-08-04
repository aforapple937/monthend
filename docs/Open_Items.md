# Open Items

In-flight work, UAT, blocked questions and follow-ups — the churn file:
regenerated at nearly every take-stock, so nothing stable lives here. Items
move out when they land somewhere permanent. Formerly `FRS9_Work_Reference.md`
§4; **item numbers are unchanged**, so older references of the form "§4 item 6"
mean item 6 here. Index: `FRS9_Work_Reference.md`. Markers: **[C]** confirmed,
**[I]** inferred, **[O]** open.

---


### 1. LOB derivation — BLOCKED, script not written

A line-of-business breakdown per account, one ordered CASE over
`RDL_AC_DTL` (`t1`): AFHP / CUL / HOUSING / GM / MSLGB / SME+ / RSME /
OTHER RETAIL (MSL catch-all) / GCT / TB / CB (MBS catch-all). Final CASE
version supplied by the user (second version — the first table format was
superseded). GCT = `CIF_NO in ('M097225','K038989','K046630','K089826')`.

Blocked on three answers **[O]**:

1. **`t2`** — the GM rule reads `t2.SRC_PROD_TYPE_CD` and `t2.CLASSIFICATION`
   (values like `Investment`), but no `CLASSIFICATION` column exists in any
   project table. Which table is `t2`, and the join key?
2. **`TC_SEG`** — holds `SMCAP` / `MDCAP` / `SME+` / `RSME`; no such column
   exists (`RDL_AC_DTL` has only `MKT_SEG`, `SUB_MKT_SEG`, `FRS_BIZ_SEG`).
   Source?
3. **Operator precedence** in the TB / CB branches: as written,
   `LEGAL_ENTITY='001' AND SYS_CODE IN (...) OR SRC_PROD_TYPE_CD IN (...)`
   makes the product clause fire regardless of entity, and the CB `NOT IN`
   twin becomes an almost-always-true catch-all. Presumed intent is
   `LEGAL_ENTITY='001' AND (SYS_CODE IN (...) OR SRC_PROD_TYPE_CD IN (...))`
   — to confirm.

### 2. EAD-after-modification-gain/loss enhancement — UAT

An enhancement (HO engine) changing EAD after modification gain/loss and EIR.
UAT compared production `masterlisting_2604` against simulation
`ntt_eadmodgainloss_2604` (both sas7bdat on the SAS server, key
`V_ACCOUNT_NUMBER`), April 2026 data. A numbered test series (test1..test7b)
was built: population match, `N_EAD_BEF_MOD_AMT` diff,
`N_MODIFICATION_GAIN_LOSS` diff (text in one file — convert to numeric,
missing = 0), `N_EAD_AMOUNT_RCY` (EAD after) diff, ECL deviation vs a
proportional estimate, with b-variants excluding accounts explained by an EAD
change. **[C]** Note `MOD_GAIN_LOSS` columns on RDL are still not covered by
`EGL Posting Check` — whether HO posts modification gain/loss remains **[O]**.

### 3. NOSTRO automation — Jul26 go-live

`MER_12_NOSTRO_Enhancement.md` holds the spec. Status:

- A UAT script (`uat_nostro_frs9.sas`) rebuilds expected NOSTRO rows from
  source per the URS and diffs against the delivered FRS9 tables; source
  library working name `FRS9PETL`. **[C]**
- Effective **Jul26 reporting**, NOSTRO ECL posting to EGL is generated and
  sent automatically by the HO engine. Manual posting only ever used the charge
  GL codes; the two **writeback** codes have now been **confirmed active** by
  EGL ops. **[C]**
- **EGL Mapping row added** for `LEGAL_ENTITY = Cash and STF`,
  `SEC_CLS_CD = AMRTCOST`, both short-term flags blank (no ST split needed).
  Because `Pre-Check TB`, `EGL Posting Check` and `Post-Posting TB Recon` all
  derive their GL scope from `SASFILES.EGL_MAPPING`, that single row extends
  all three. **[C]**
- **Still open for the Jul26 run [O]:**
  - `Balance Recon` reads a separate `tb_mapping`, so NOSTRO still needs a
    `RECON_GRP` there. Deliberately deferred.
  - The new mapping row should carry the product-agnostic `EIR_BS` / `EIR_PNL`
    / `FVOCI_BS` / `FVOCI_OCI` GLs that every other row has, so a stray
    `LCY_EIR_ADJ_AMT` doesn't fall out.
  - Verify on the Jul26 RDL: `F_SHORT_TERM_IND` and `F_SHORT_TERM_INCEP_IND`
    blank on `RDL_MSTR_LIST` for NOSTRO (if the engine sets them `Y`, the
    lookup key becomes `CASH AND STF|AMRTCOST|Y|Y` and misses the blank row,
    dropping every NOSTRO line into `exp_excep`); `SRC_PROD_TYPE_CD =
    SG_NOSTRO`; `SEC_CLS_CD = AMRTCOST`; and `AC_MGR_UNIT_CODE = 22121` — that
    last one is the RC segment, and a blank there yields a malformed account
    string rather than an exception row.

### 4. EIR — AEL refresh position

Detail and open points: **`Accounting_Positions.md` §5.1**. In one line: AEL is refreshed annually
but applied to new accounts only, whereas IFRS 9 B5.4.6 defaults to a catch-up
on the existing book. **[O]** — position not yet agreed with technical
accounting / audit.

### 5. Sector MOA (management overlay)

Detail and open points: **`Accounting_Positions.md` §5.2**. In one line: PDFL overlay repurposed as
an ME-conflict sector overlay, peak Mar25-cohort migration rate applied to
May26 Stage 1 exposures, S$41–46m proposed for 30 Jun booking. **[O]** — final
booking outcome and MOA clearance.

### 6. `V_T_CIF_MSTR` — can a CIF exceed 7 characters?

`CIF_NO` is `$7` on `LBDWH.V_T_CIF_MSTR` against `$50` on `PARTY_MSTR` and
`RDL_AC_DTL` (widths and the hash-key behaviour in `SAS_Tables_Knowledge.md`).
If any live CIF is longer than 7 characters it cannot be represented on the
view, and `ECL Flux` (§11.10), `FVOCI Loan MTM` (§11.12), `Overlay Watchlist`
(§11.14) and `ECL Manual Override` (§11.15) would all return a blank name for
it — silently, since a blank name looks the same as a closed customer. **[O]**

§11.10 joined the exposed list in July 2026 when it moved its name lookup off
`PARTY_MSTR` and onto the view. It is the least visible of the four: the
process prints only entity and segment totals, so a nameless borrower never
reaches the page and the blank sits unread in `MTH.ECLFLUX`.

Sharper now that §11.15 exists: that process takes a **hand-supplied CIF list**,
so a borrower with an over-length CIF would be typed in deliberately and come
back nameless, which is more visible than the other two but also more likely to
be noticed mid-close.

Cheap to settle: `max(lengthn(strip(CIF_NO)))` over a month of `RDL_AC_DTL`. If
it comes back 7, the widths are cosmetic and this can be closed. If longer,
`UCIF_NO` (`$50`, same view) is the first place to look.

### 7. Missing §5.3

A **§5.3** was referenced for the `DISCOUNT` question — now
`Accounting_Positions.md`, which has only §5.1 and §5.2; no §5.3 exists. Either
a note was drafted and lost, or the reference was written ahead of it. **[O]**
what it was meant to hold.

The pointer lived in §11.12's "Dropped from the original" section, removed
Aug 2026 at the user's request. The underlying question stands on its own:
`FVOCI Loan MTM` has no discount adjustment between `MKT_VALUE_TOTAL` and
`LCY_END_PERIOD_BAL`, and whether it should is unsettled. **[O]**

### 8. `_<yymm>` suffix on `MTH` output tables — decide one way

The pack is now split. `SORA Rate Patch` (§11.5) and `ECL Manual Override`
(§11.15) carry **no** suffix, on the reasoning that the per-month output folder
already scopes them and an unsuffixed name makes the Enterprise Guide export
default to the right filename. `Balance Recon` (§11.2) has been moved to the
same footing — `MTH.BALRECON` and `MTH.BALDETAIL` — and so has `EIR AEL
Adjustment` (§11.11), where the posting file is now `GLTE.EIR_AEL_ENTRIES` in a
`glte` subfolder inside the month folder rather than `OUT.EIR_AEL_ENTRIES_<yymm>`
sitting loose in it. The subfolder does the scoping the suffix used to do, and
nothing reads the table by name.

`FVOCI Loan MTM` (§11.12) followed in July 2026 — `MTH.FVOCIMTM`,
`MTH.FVOCIWAIR`, and the GL upload as `GLTE.FVOCI_MTM_ENTRIES` in the same
`glte` subfolder. Two processes now write there, which settles the shape:
**`glte` is where a month's GL upload files go, whichever process built them.**
**[C]**

`EIR Future Repricing Adjustment` (§11.13) followed in July 2026 — the posting
file is now `GLTE.FUT_REPRICING_ENTRIES` rather than
`OUT.FUT_REPRICING_ENTRIES_<yymm>`. Third process on the precedent, and the
first where a **patch file for IT sat alongside a GL upload**: `OUT.FRS9_EIR`
stayed in the month folder while only the upload moved. That draws the line
`glte` actually holds — a month's GL upload files, not its output files
generally. **[C]**

`ECL Manual Override` (§11.15) followed on 2 Aug 2026 — the GL upload is now
`GLTE.ECL_OVERRIDE_ENTRIES` rather than `MTH.ECL_OVERRIDE_ENTRIES`. Fourth
process on the precedent, and the second of the §11.13 shape: `MTH.FRS9_CLOSING_BAL`
and `MTH.RCY_TO_PATCH` stayed loose in the month folder while only the upload
moved. The line §11.13 drew now has two processes behind it rather than one, so
it is no longer a single case — **`glte` holds a month's GL upload files; patch
files for IT stay loose in the month folder.** **[C]**

Note the one output in the pack that keeps a month tag **on purpose**:
`FUTREP.FUT_REPRICING_<yymm>` (§11.13). It is not a `<yymm>`-folder output — it
is one dataset per month in a single retained folder, read back by name the
following month, and the tag is what makes the write idempotent. It is outside
this decision entirely. **[C]**

`Pre-Check TB` (§11.1) has left the question altogether: `MTH.PRECHECK_<yymm>`
is gone and the process now prints only, with no `MTH` library at all. That
sets a cleaner precedent than stripping the suffix — **for a pure exception
check, the printed exception list is the deliverable and the table is
scaffolding.** Worth applying the same test to `valchk`, `eglrev`, `postchk`
and `postrecon` before deciding anything about their names — stripping a
suffix, as §11.9 has now done, leaves that question untouched. **[O]**

`EGL Reversal Check` (§11.7) took the lesser step in July 2026 — the table is
kept but the suffix is gone, `MTH.EGLREV`. Nothing reads it by name, so the
month folder does the scoping. It is still an exception check, so the print-only
question above remains open for it; stripping the suffix does not settle that.
**[C]**

`EGL Posting Check` (§11.8) followed on the same footing in July 2026 —
`MTH.POSTCHK` and `MTH.POSTDTL`. Note this cuts both ways for `POSTDTL`, which
is not an exception table but the drill-down behind one: it is the only place
the accounts feeding a difference can be seen, so the print-only test above
must not be applied to it. `MASTERLISTING_<yymm>` keeps its suffix in the same
script — it is an input, and that is how the extract is named. **[C]**

`ECL Flux` (§11.10) followed in July 2026 — `MTH.ECLFLUX`. Nothing reads it by
name and the month folder does the scoping, so it is the same lesser step
§11.7 and §11.8 took. Note it does **not** settle the print-only question for
this process the way it might elsewhere: §11.10 now prints a three-line summary
while the table holds the borrower-level detail behind it, so the table is the
only place the drivers can be seen — the same shape as `POSTDTL`, and the
print-only test must not be applied to it. **[C]**

`Post-Posting TB Recon` (§11.9) followed on 2 Aug 2026 — `MTH.POSTRECON` and
`MTH.POSTRECONDTL`, taken together as the paragraph below anticipated. Same
shape as §11.8: an exception table plus the drill-down behind it, so the
print-only test must not be applied to `POSTRECONDTL` either — with FVOCI
collapsing every account in an entity and currency onto one account string, it
is the *only* way to see which accounts fed an FVOCI difference. **[C]**

Two outputs still carry the suffix: `valchk` and `ccy_change`.

`sora_verify_ln` and `sora_verify_rt` left the list in July 2026 the way
`PRECHECK` and `overlaymon` did — §11.6 now persists nothing and both tables
live in `WORK`. Third process on the print-only precedent, and the strongest of
the three for the open question below: unlike those two it *was* writing
full-population tables, and dropping them was still the right call because
nothing read them and the comparison is reproducible from the patch tables in
the same folder. **That is the test to apply to `valchk`, `eglrev`, `postchk`
and `postrecon`: not "is it an exception check" but "can it be rebuilt from
inputs that are still there."** **[C]**

`overlaymon` has left the list the way `PRECHECK` did — §11.14 was renamed
`Overlay Watchlist` in July 2026 and its table dropped entirely, so the printed
report is the deliverable and no `MTH` library is assigned. That is now the
second process on that precedent, and the first that is **not** an exception
check: a monitoring report was judged the same shape as one, because nothing
downstream reads it. Weighs in favour of the print-only test for `valchk`,
`eglrev`, `postchk` and `postrecon`. **[C]**

Decide whether to strip the rest. **The suffix must be kept wherever a process
reads a prior month by name** — `FUT_REPRICING_<yymm>` in §11.13 is the
example, where the month tag is how last month's figures are found. Pure
outputs, read by nobody, don't need it. **[O]**

### 9. `RDL_MSTR_LIST` month probe — §11.8 and §11.9 fixed, §11.15 unchecked

`EGL Posting Check` (§11.8) and `Post-Posting TB Recon` (§11.9) probe whether
the month has loaded before falling back to `MTH.MASTERLISTING_<yymm>`. The
server copies do it with `obs=1` plus a `datepart(PROC_DTE)` `WHERE`, which
**does not work**: the filter cannot be pushed down to Oracle, so the engine
applies the row limit and SAS filters afterwards — one arbitrary physical row
is tested, and RDL holds every month of the year. The probe therefore reports
"not loaded" for months that are loaded.

Consequence, and the reason this is worth chasing rather than filing: neither
process stops. Either the master listing has been quietly taken from the
`MASTERLISTING` extract instead of `RDL_MSTR_LIST`, or — where the extract was
absent — the run proceeded on an empty master listing, sending segment 7 to
`0000` for every Islamic account and segment 5 to `000` for anything with a
parent group. Both then surface as account-level differences against HO's file
or the trial balance, which read like posting breaks rather than a missing
table.

Two actions **[O]**:

1. **Search recent logs of both processes** for
   `WARNING: RDL_MSTR_LIST not loaded`. Its presence tells you which months ran
   off the extract.
2. **Update the server copies** to the corrected probe — a `PROC SQL` count over
   a datetime range on the raw column, which pushes down and is exact. The
   reference copies in §11.8, §11.9 and §11.15 already carry it, so the
   reference is currently *ahead* of runtime on this one block.

**§11.8 is now closed. Confirmed 31 Jul 2026** by reading the stored process
source: the `EGL Posting Check` runtime copy has been brought onto the
reference — corrected `PROC SQL` probe, `V_CUSTOMER_PARENT_GROUP_NAME` back to
`$30`, and the EGL Mapping header comment now describing the single exact-match
lookup the code actually performs. All three drift markers recorded on 30 Jul
are gone, so the server was updated in between. **[C]**

**§11.9 is now closed too. Confirmed 2 Aug 2026** by reading the stored process
source — and unlike §11.8 it was still broken when read: the runtime copy
carried the `data _null_` / `obs=1` probe, `V_CUSTOMER_PARENT_GROUP_NAME` at
`$255`, and no explanatory comment. All three were corrected on both sides the
same day, the reference copy having been right already. So the drift this item
predicted was real and has now been observed directly on one of the three
processes, not merely inferred. **[C]**

§11.15 has **not** been inspected — same probe, same expected drift, still
unverified. That is all that is left of this item. Look for the same three
markers: the `data _null_` probe, the `$255` width, and the missing comment.
**[O]**

Action 1 above still stands regardless of the fixes: the probe was wrong for
some period, so past months may have run off the `MASTERLISTING` extract, and
the logs are the only record of which. §11.9 is the more revealing of the two
to search, because its fallback logs only a `WARNING` and the run completes and
reconciles against the extract — quieter than the name suggests.

On the third branch of `%get_mstr`, which writes `ERROR:` and continues into an
empty master listing rather than stopping: **left as it is, decided 31 Jul
2026** — the `ERROR:` in the log is the control, and the log is read every run.
**[C]** Still present in every copy, reference and runtime alike; the §11.8
update did not touch it, and no change is planned.

Worth knowing what the log line is protecting against, since the run itself
gives no sign. With the master listing empty, `V_FINANCING_CODE` and
`V_CUSTOMER_PARENT_GROUP_NAME` are blank for every account, so segment 7 goes
to `0000` for Islamic accounts and segment 5 to `000` for anything with a
parent group — while the two short-term flags, also blank, still match the EGL
mapping, because blank matches blank. The GL lookup therefore **succeeds**,
`exp_excep` stays empty, and the run produces a full and plausible-looking
expected posting built on wrong account strings. Nothing in the output says so;
the log line is the only signal, and it surfaces otherwise as differences
against HO's file that read like posting breaks.

### 10. `CFS-IND` — sub-segment literal never verified against data

`ECL Flux` (§11.10) prints an MSL line filtered on
`upcase(strip(MKT_SUB_SEG_DESC)) = "CFS-IND"`. The literal came from the user
in July 2026 and has **not been checked against `PARTY_MSTR`** — the string
appears nowhere else in this pack, and the only sub-segment value list on file
(`MKT_SUB_SEGMENT` on `RDL_MSTR_LIST`) is a different column with a different
domain, so it neither confirms nor denies it. **[O]**

Why it matters: a wrong literal matches no rows and the line prints `0.00`,
which is indistinguishable from a real nil caused by offsetting movements. The
`COALESCE` that keeps the line on the page when nothing matches is what makes
the failure quiet — the line is present and looks answered.

Cheap to settle, one run:

```sas
proc freq data=mth.eclflux;
    tables MKT_SUB_SEG_DESC / missing;
    where ENTITY = "MSL";
run;
```

If the value is spelt differently there, fix the literal in `CODE_ecl_flux.txt`
and the server copy together. If it is right, record the confirmation in
`SAS_Tables_Knowledge.md` with the rest of the segment note and close this.

### 11. Reference-vs-runtime sweep, 31 Jul – 2 Aug 2026

Eleven stored processes were read off the SAS server and compared line by line
against their `CODE_*.txt` reference copies. Recorded so it need not be redone,
and so the next drift has a baseline to be measured from.

**In sync — ten processes. [C]**
`balance_recon`, `posting_check`, `egl_reversal`, `eir_ael_adj`,
`eir_fut_repricing`, `fvoci_mtm`, `overlay_watchlist`, `precheck_tb`,
`sora_verify`, `sora_patch`. Three of them differ by a single blank line inside
a `PROC PRINT` or `PROC REPORT` — cosmetic, no behaviour, not worth
regenerating a CODE file over. Note that blank lines of this kind exist inside
both copies of `overlay_watchlist` (one sits in the middle of a `PROC SORT`),
so they are in the source rather than an artefact of copying.

**Out of sync — one. [C]** `post_recon`, on the probe block; see item 9. Fixed
both sides 2 Aug.

**Not compared — five.** `ccy_change`, `ecl_override`, `val_ln`, plus the setup
scripts `map_setup`, `valid_values_setup` and `load_prior_futrepricing`.
`ecl_override` is the one that matters, being §11.15 and the last unchecked
probe.

`ecl_flux` is excluded from the count: it was compared and found to differ, but
because the process had genuinely changed rather than drifted, and both copies
were reissued on 31 Jul.

### 12. `CODE_eir_ael_adj.txt` has no `*ProcessBody;`

Every other stored process in the pack opens with `*ProcessBody;`. §11.11 does
not — the only three other CODE files without it are `map_setup`,
`valid_values_setup` and `load_prior_futrepricing`, which are one-off setup
scripts run interactively and so do not need it. **[C]**

Why it should matter here: the script's first executable line is
`%let TARGET_MONTH = %sysfunc(inputn(&PROC_DTE, date9.));`, so it consumes the
prompt immediately, and `*ProcessBody;` is what makes the generated prompt code
land above the code that uses it (`FRS9_Work_Reference.md` §3).

Why it may not: the process runs correctly every month, so either the server
copy carries the line and the reference lost it, or something else about this
one makes it unnecessary. The paste compared on 31 Jul was byte-identical to
the reference, but its provenance — server or project — was never established,
so the question is genuinely open rather than merely unchecked. **[O]**

Cheap to settle: open the stored process and look at line 1. If the line is
there, close this. If it is not, the interesting question is why §11.11 works
without it when §3 says it should not — and the answer probably belongs in §3.

**Aug 2026: the marker was added to `CODE_eir_ael_adj.txt` on instruction, with
the server still unchecked.** So the reference copy now asserts a line whose
presence on the server is unverified — the opposite of the usual divergence, and
worth settling for that reason. Adding it is harmless either way: in a plain EG
program `*ProcessBody;` is only a comment statement. **[O]**

### 13. `datepart(PROC_DTE)` rollout — 5 scripts done, 21 files to go

A `datepart()` month filter does not push down to Oracle, so every retained
month crosses the connection to be filtered in SAS. Measured between 4× and 14×
on every shape tried; figures and the standing rule are in
`SAS_Tables_Knowledge.md`. Being rolled through the month-end scripts one at a
time, each measured before it is changed.

**Changed Aug 2026** — reference copies regenerated; **each still has to reach
the stored process on the server, which is runtime truth.** Until it does, the
`CODE_*.txt` claims a change that is not live. **[C]**

| Step | Script | Filters | Result |
|---|---|---|---|
| §11.2 | `CODE_balance_recon.txt` | 1 | 56.7s → 4.0s |
| §11.5 | `CODE_sora_patch.txt` | 3 | 48.3s → 5.5s |
| §11.6 | `CODE_sora_verify.txt` | 2 | not timed |
| §11.11 | `CODE_eir_ael_adj.txt` | 2 | not timed |
| §11.12 | `CODE_fvoci_mtm.txt` | 4 | 59.1s → 4.7s; whole run 103s → ~25s |

**Not yet done.** §11.3 (`ccy_change`) and §11.4 (`val_ln`) were deliberately
skipped and not looked at; §11.4 is still in build (item above) and has four
filters including one taking the month as a macro parameter, so it may be better
finished than patched. Remaining: §11.3, §11.4, §11.7 `egl_reversal`, §11.8
`posting_check`, §11.9 `post_recon`, §11.10 `ecl_flux`, §11.15 `ecl_override`.

`CODE_ecl_override.txt`, `CODE_post_recon.txt` and `CODE_posting_check.txt` are
the interesting ones: each already uses datetime literals for the month-presence
probe (item 9) and `datepart()` for the read a few lines below. The knowledge was
there, applied for correctness and not for cost. The macro variables to reuse
already exist in those files. **[C]**

Also outstanding: the 15 remaining `__COLUMN.txt` derivations in the lineage
library still use `datepart()`. Reference material rather than monthly work, so
low priority — noted in `SAS_Tables_Knowledge.md`.

### 14. `FVOCI Loan MTM` — `V_T_CIF_MSTR` sort removed, one thing to confirm

The ~2.05m-row `nodupkey` sort feeding the name lookup was dropped and the hash
now loads straight from the view (§11.12). Two follow-ups:

1. Confirm `CIF_NAME` is populated in `MTH.FVOCIMTM` and not blank on every row
   — the `$7`/`$50` `CIF_NO` mismatch in item 6 would make it silently blank,
   and that failure predates this change rather than being caused by it. **[O]**
2. The step was 41.4s in one run and 17.6s in the next with no code change
   between them, so single timings on this server carry noise of that scale.
   The 4×–14× filter results are far outside it, but a change measured at less
   than ~2× should be run more than once before it is believed. **[I]**
