# Accounting Positions

Technical accounting positions and working notes. Formerly
`FRS9_Work_Reference.md` §5; **section numbers 5.1 / 5.2 are kept**, so older
references still resolve. One-line summaries and the live open points sit in
`Open_Items.md` (items 4 and 5). Index: `FRS9_Work_Reference.md`.

---

## 5.1 EIR - AEL refresh (working note)

**Purpose:** working note on whether the annual AEL refresh must be applied to the existing loan book, and what justifications are available under IFRS 9 for applying it to new accounts only.

---

#### 1. Current approach

- EIR adjustment recognised to move interest income from contractual rate to effective interest rate (IFRS 9).
- Key assumption: **average expected life (AEL)** over which loans are assumed to run.
- AEL derived from a rolling **5-year historical average**, refreshed **annually**.
- On refresh, the new AEL is applied to **new accounts only** (e.g. a Jan 2026 refresh applies to Jan 2026 originations onwards). **Existing accounts remain on the AEL in force at their booking date.**

---

#### 2. The IFRS 9 default position

An AEL refresh is a **change in accounting estimate**. IFRS 9 prescribes a specific mechanism for existing instruments when estimates of expected cash flows (including expected life) change:

##### IFRS 9 B5.4.6 — catch-up approach

1. **The original EIR is retained.** For a fixed-rate loan the discount rate stays locked at origination.
2. **The gross carrying amount is recalculated** as the present value of the *revised* expected cash flows, discounted at that original EIR.
3. **The difference goes immediately to P&L** as a catch-up adjustment.
4. **Remaining amortisation re-profiles** over the revised expected life.

##### Key distinction — "prospective" ≠ "new accounts only"

| Term | What it actually means |
|---|---|
| Prospective application (IAS 8) | Do **not** restate prior periods (no reopening of FY2024/FY2025) |
| What it does **not** mean | Confining the revised estimate to newly originated accounts |

Under the default, the revised estimate flows through the **existing** book from the date of change onward, via the catch-up. Freezing existing accounts on the old AEL effectively ignores the estimate change for those loans.

##### Diagnostic question

Is the refresh capturing:

- **(a)** genuinely different behaviour of **new vintages** — different product, pricing, or customer mix at booking; or
- **(b)** a refined estimate of the behavioural life of the **same population**, existing loans included?

A rolling pooled 5-year average is almost always doing **(b)**. If borrowers are prepaying faster than assumed, that is true of loans already on the book — precisely the situation B5.4.6 addresses.

##### Directional impact (illustrative)

Loan booked with net deferred fee **income** released over an assumed 5-year life; two years in, AEL is cut to 4 years:

- Remaining deferred income must now be earned over **two** years instead of three.
- Result: **immediate catch-up increasing income**, plus acceleration of the remainder.
- A **lengthening** AEL defers income instead.
- Sign **flips** where the loan carries net deferred **costs** rather than income.

Immaterial on a single loan; potentially very material across a back-book where the AEL has genuinely moved.

---

#### 3. Available justifications for the current approach

##### Route 1 — Vintage / cohort argument (justifies the approach *on principle*)

B5.4.6 is only triggered if the estimate of an **existing** loan's expected life has changed. If the refresh reflects different behaviour of **new origination cohorts** — new product features, new pricing, a new refinancing channel, a different customer mix at booking — then the existing loans' estimate has not changed and no catch-up arises for them. On this reading, applying the new AEL to new accounts only is **correct**, not an expedient.

> **Constraint:** a rolling 5-year **pooled** average generally will not support this. The methodology must genuinely estimate life **per origination cohort**, with each cohort locked to the conditions at its booking date.
>
> **Action:** confirm whether the current methodology does this or simply pools all data.

##### Route 2 — Materiality (justifies the *deviation*, not the principle)

The position most commonly relied on in practice, and a legitimate one:

- If the catch-up impact of applying the refreshed AEL to the existing book is **immaterial**, it need not be booked.
- Requires: documented assessment, **quantification** of the foregone catch-up, demonstration that it falls below threshold, and auditor acceptance of the new-business-only application as a practical simplification.
- Rests entirely on **the number** — no principle in the standard permits freezing accounts.
- The AEL drifts each refresh cycle, so the cumulative gap on the back-book **compounds**. Materiality must be **re-tested annually**, not concluded once.

##### What will not survive audit scrutiny

> "This is a change in estimate, changes in estimate are applied prospectively under IAS 8, therefore we only apply it to new accounts."

Prospective means **future periods**, not new accounts. IAS 8.36 read together with B5.4.6 points **toward** the catch-up, not away from it. The justification must be the cohort argument or materiality.

##### Intermediate option if materiality is tight

Apply the refreshed AEL to existing accounts but **re-profile future amortisation only**, without booking a separate catch-up entry. Still leans on materiality, but keeps the existing book on a **current** estimate — a softer position to defend than existing loans never receiving the update at all.

---

#### 4. Portfolio-level application

If the EIR adjustment is genuinely portfolio-level rather than instrument-level, **IFRS 9 B5.4.7** permits revision of estimates on a **portfolio basis**. Note this still requires revision **for the existing portfolio** — it does not permit freezing it.

---

#### 5. Next steps

1. Confirm whether the AEL methodology is **cohort-based** or **pooled** — this determines whether Route 1 is available. This is the blocking answer: cohort makes current practice correct on principle; pooled leaves only the materiality route, re-tested annually.
2. **Quantify** the catch-up impact on the existing book at the most recent refresh, to test the materiality route.
3. Review the **accounting policy wording** on AEL refresh application for consistency with whichever route is taken.
4. Document the assessment and **agree the position with external audit**.
5. Set an annual control to **re-test materiality**, given cumulative drift.

---

*Working note only. Not audit or professional accounting advice — conclusions depend on the specific products, methodology wording, materiality thresholds and positions agreed with external auditors. To be reviewed with technical accounting and external audit.*

## 5.2 Sector MOA (ME conflict) - summary

**Reporting date:** 30 June  
**Estimated incremental overlay:** S$41m – S$46m  
**Status:** Discussed with EYSG; cleared through local governance

---

#### 1. Context

The existing PDFL overlay is being repurposed as a **sector overlay** to capture expected credit deterioration arising from the ME conflict. The overlay captures anticipated Stage 1 → Stage 2 migration that is not yet reflected in the underlying ECL model.

#### 2. Methodology

1. **Fixed reference cohort** — the Stage 1 population as at **March 2025** is taken as a fixed cohort.
2. **Migration tracking** — the proportion of that cohort migrated to Stage 2 is tracked at each subsequent month-end across the observation period (**April 2025 to May 2026**).
3. **Stressed assumption** — the **maximum (peak)** migration rate observed over the period is selected, as a prudent/stressed assumption.
4. **Application** — the peak rate is applied to **May 2026 Stage 1 exposures** for:
   - borrowers in affected industries; and
   - separately identified ME-affected borrowers.
   
   This proxies the exposure expected to migrate to Stage 2 in June 2026.
5. **ECL impact** — the estimated migrating exposure is multiplied by the **Stage 2 ECL coverage ratio as at May 2026** to derive the incremental ECL.

#### 3. Affected industries (identified by Risk)

- Cement
- Chemicals/pharmaceuticals
- Commodity traders
- Construction/Developers
- Data centers
- Food/F&B/related
- Metals & mining/steel
- Power & Utilities
- Sectors dependent on refining products (petrochemicals, plastics, fertilisers, paints, etc.)
- Semiconductors
- Tourism and hospitality
- Transportation (shipping, airlines, road)

#### 4. Open points to resolve

- [ ] **"ME" abbreviation** — expand to the full term in any document that goes beyond the immediate team, so reviewers/auditors aren't left guessing.
- [ ] **Observation window inconsistency** — stated as both *Apr25–May26* and *"all the way until March26"*. Confirm which is correct; the summary above assumes **Apr25–May26** (consistent with a May 2026 application base). If the tracking is capped at a 12-month horizon (Mar25 → Mar26), amend throughout.
- [ ] **Justification for peak rate** — auditors commonly probe why the *maximum* was selected rather than the latest observed or an average. Prepare the rationale (typically prudence given elevated sector uncertainty).
- [ ] **HO / Group Risk discussion** — content unknown locally; confirm whether anything from that channel needs to be factored in, or handle as a separate step post-close.
- [ ] **Timing constraint** — MOA clearance cannot be obtained after 30 June for 30 June reporting.

---
