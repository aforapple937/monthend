%let rpt_mth     = 30APR2026;
%let rpt_dt      = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm     = "&rpt_mth:00:00:00"dt;
%let nxt_dtm     = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

/*--------------------------------------------------------------------------
  ALLOCATED_COST derivation - new loans pro-rata allocation of GL movement

  RSME split (this version):
    - GL 634097 (within CPPTYLN) and GL 863461 (within ISLMCPPTYLN) are
      "RSME-only" GL accounts. Their month-on-month movement is allocated
      ONLY to new loans belonging to RSME customers.
    - All other GL accounts (the "general" pool) continue to be allocated
      across ALL new loans in the product group, RSME or not. An RSME loan
      therefore receives a share of BOTH pools; a non-RSME loan receives a
      share of the general pool only.
    - RSME status is sourced from
      LBFRS9.T_MTH_RSME_CMPLX_PRD_WRK_TBL.RSME_IN_OUT_FLG = 'IN', joined to
      the loan population on CIF_NO and filtered to the reporting month.
      Any CIF not found / any other flag value is treated as non-RSME.
    - Empty-bucket rule: if a group has RSME-GL cost but no RSME new loans,
      that cost is left UNALLOCATED.

  Steps:
    1. Pull current month loans (+CIF_NO), prior month FRS9 AC_CODEs,
       repriced AC_CODEs, and the RSME CIF list into separate WORK tables
    2. Identify new loans and tag each with RSME_FLG
    3. Pull GL balances for current and prior month, map GL accounts to
       product groups, tag each GL as RSME-pool or general-pool, and
       compute TOTAL_COST as the month-on-month movement
    4. Compute group-level cost pools (general vs RSME) and group-level
       LCY_TOT_OS denominators (all loans vs RSME loans only)
    5. Allocate the general pool pro-rata across all loans and the RSME
       pool pro-rata across RSME loans; ALLOCATED_COST is the sum
    6. Drop intermediate WORK tables, keeping NEW_LOANS_ALLOCATED and
       GL_COST_DETAIL

  Note on January:
    - prev_mth in January resolves to Dec of the prior FY, which is not
      the right cost basis. For January, TOTAL_COST = current GL only.

  Assumptions to confirm (no metadata available for these objects):
    - LBFRS9.T_MTH_RSME_CMPLX_PRD_WRK_TBL.PROC_DTE is a SAS datetime
      (DATETIME20.) like the other FRS9 tables, so the bounded datetime
      literals below apply to it.
    - RSME status is taken as at &rpt_mth.
    - CIF_NO is keyed consistently between LBDWH.V_T_MTH_AC_DTL and the
      RSME table so the join matches.
--------------------------------------------------------------------------*/

%let rpt_mth_num = %sysfunc(month(&rpt_dt));
%let prev_mth    = %sysfunc(intnx(month, &rpt_dt, -1, end));
%let prev_dtm    = "%sysfunc(putn(&prev_mth, date9.)):00:00:00"dt;
%let prv_nxt     = "%sysfunc(putn(%eval(&prev_mth + 1), date9.)):00:00:00"dt;

/*--------------------------------------------------------------------------
  STEP 1a: Current month loans
  ---------------------------------------------------------------------------
  Filter to CO_CODE 003, the four product codes, positive balance, and
  credit status 1. CIF_NO is now selected so the RSME flag can be derived
  downstream.
 -------------------------------------------------------------------------*/
proc sql;
    create table WORK.curr_loans as
    select  PROC_DTE
          , AC_CODE
          , CIF_NO
          , BIZ_PRD_CODE
          , LCY_TOT_OS
          , case
                when BIZ_PRD_CODE = 'CPPTYLN'           then 'CPPTYLN'
                when BIZ_PRD_CODE in ('HL','HDBHL')     then 'HL_HDBHL'
                when BIZ_PRD_CODE = 'ISLMCPPTYLN'       then 'ISLMCPPTYLN'
            end as PRD_GRP length=20
    from LBDWH.V_T_MTH_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and CO_CODE = '003'
      and LCY_TOT_OS > 0
      and CR_STS_CODE = '1'
      and BIZ_PRD_CODE in ('CPPTYLN','HDBHL','HL','ISLMCPPTYLN')
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 1b: Prior month FRS9 loan AC_CODEs
  ---------------------------------------------------------------------------
  Distinct AC_CODE list - used to exclude existing loans from the new
  loan set.
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.prev_loans as
    select distinct AC_CODE
    from LBFRS9.T_MTH_FRS9_LN_DTL
    where PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 1c: Repriced AC_CODEs in current month
  ---------------------------------------------------------------------------
  Repriced loans (MSG_TYP_CODE = '400') are excluded from the new loan
  set even if they don't appear in prior month FRS9.
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.repriced as
    select distinct AC_CODE
    from LBDWH.T_MSG_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and MSG_TYP_CODE = '400'
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 1d: RSME CIF list for the reporting month
  ---------------------------------------------------------------------------
  RSME customers are those flagged RSME_IN_OUT_FLG = 'IN' in the RSME
  complex-product work table at &rpt_mth. The table holds historical data,
  hence the PROC_DTE filter. Distinct CIF_NO prevents fan-out on the join.
  Pulled to WORK first to avoid a cross-library ODBC join in the loan step.
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.rsme_cifs as
    select distinct CIF_NO
    from LBFRS9.T_MTH_RSME_CMPLX_PRD_WRK_TBL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and RSME_IN_OUT_FLG = 'IN'
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 2: Identify new loans and tag RSME status
  ---------------------------------------------------------------------------
  Left join curr_loans against prev_loans and repriced; keep only rows
  with no match in either (genuinely new and not repriced). Additionally
  left join the RSME CIF list: RSME_FLG = 'Y' when the loan's CIF is in
  the list, else 'N' (covers both not-found and any non-'IN' flag).
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.new_loans as
    select  c.PROC_DTE
          , c.AC_CODE
          , c.CIF_NO
          , c.BIZ_PRD_CODE
          , c.LCY_TOT_OS
          , c.PRD_GRP
          , case when rs.CIF_NO is not missing then 'Y' else 'N' end
                                                   as RSME_FLG length=1
    from        WORK.curr_loans  as c
    left join   WORK.prev_loans  as p   on c.AC_CODE = p.AC_CODE
    left join   WORK.repriced    as r   on c.AC_CODE = r.AC_CODE
    left join   WORK.rsme_cifs   as rs  on c.CIF_NO  = rs.CIF_NO
    where p.AC_CODE is missing
      and r.AC_CODE is missing
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 3a: GL balances at individual GL_AC_CODE level
  ---------------------------------------------------------------------------
  Filter to CO_CODE 003. GL accounts are mapped into the same three
  product groups as the loans:
    - CPPTYLN     : GL 634095, 634097, 634099
    - HL_HDBHL    : GL 634094, 634096, 651652 with UNIT_CODE 013 or 073
    - ISLMCPPTYLN : GL 863451, 863461, 863480

  Each GL is also tagged into a cost pool:
    - RSME : GL 634097 and 863461 (allocated to RSME loans only)
    - GEN  : all other GLs        (allocated to all loans)

  Output is at GL_AC_CODE granularity, with conditional sums producing
  current and prior month balances side by side. TOTAL_COST is the
  month-on-month movement.

  For January, only the current month is queried and TOTAL_COST equals
  the current GL balance.

  Wrapped in a macro because nested %if blocks are not allowed in open
  code.
--------------------------------------------------------------------------*/
%macro build_gl_cost_detail;

    proc sql;
        create table WORK.gl_cost_detail as
        select  GL_AC_CODE
              , case
                    when GL_AC_CODE in ('634095','634097','634099')
                        then 'CPPTYLN'
                    when GL_AC_CODE in ('634094','634096','651652')
                        then 'HL_HDBHL'
                    when GL_AC_CODE in ('863451','863461','863480')
                        then 'ISLMCPPTYLN'
                end as PRD_GRP length=20

              /* RSME-only GL accounts form their own cost pool */
              , case
                    when GL_AC_CODE in ('634097','863461')
                        then 'RSME'
                    else 'GEN'
                end as COST_POOL length=4

              /* current month GL sum */
              , sum(case when PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
                         then LCY_AGR_BAL else 0 end) as LCY_AGR_BAL_CURR

        %if &rpt_mth_num ne 1 %then %do;
              /* prior month GL sum */
              , sum(case when PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt
                         then LCY_AGR_BAL else 0 end) as LCY_AGR_BAL_PREV

              /* month-on-month movement */
              , calculated LCY_AGR_BAL_CURR - calculated LCY_AGR_BAL_PREV
                                                           as TOTAL_COST
        %end;
        %else %do;
              /* January: TOTAL_COST = current GL */
              , calculated LCY_AGR_BAL_CURR                as TOTAL_COST
        %end;

        from LBDWH.T_DAL_GLBAL
        %if &rpt_mth_num ne 1 %then %do;
        where ( (PROC_DTE >= &rpt_dtm  and PROC_DTE < &nxt_dtm)
             or (PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt) )
        %end;
        %else %do;
        where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
        %end;
          and CO_CODE = '003'
          and (
                  GL_AC_CODE in ('634095','634097','634099')
               or ( GL_AC_CODE in ('634094','634096','651652')
                    and UNIT_CODE in ('013','073') )
               or GL_AC_CODE in ('863451','863461','863480')
              )
        group by GL_AC_CODE, calculated PRD_GRP, calculated COST_POOL
        order by PRD_GRP, COST_POOL, GL_AC_CODE
        ;
    quit;

%mend build_gl_cost_detail;

%build_gl_cost_detail;

/*--------------------------------------------------------------------------
  STEP 3b: Roll up to PRD_GRP level, splitting cost into pools
  ---------------------------------------------------------------------------
  GRP_GEN_COST  : movement of the general GLs   -> all new loans
  GRP_RSME_COST : movement of GL 634097 / 863461 -> RSME new loans only
  GRP_TOTAL_COST: full movement, retained for reconciliation
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.gl_cost_by_grp as
    select  PRD_GRP
          , sum(LCY_AGR_BAL_CURR) as LCY_AGR_BAL_CURR

          %if &rpt_mth_num ne 1 %then %do;
          , sum(LCY_AGR_BAL_PREV) as LCY_AGR_BAL_PREV
          %end;

          , sum(case when COST_POOL = 'GEN'  then TOTAL_COST else 0 end)
                                              as GRP_GEN_COST
          , sum(case when COST_POOL = 'RSME' then TOTAL_COST else 0 end)
                                              as GRP_RSME_COST
          , sum(TOTAL_COST)                   as GRP_TOTAL_COST
    from WORK.gl_cost_detail
    where PRD_GRP is not missing
    group by PRD_GRP
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 4: Group total LCY_TOT_OS for the pro-rata denominators
  ---------------------------------------------------------------------------
  GRP_TOTAL_OS : all new loans in the group   -> general pool denominator
  GRP_RSME_OS  : RSME new loans only           -> RSME pool denominator
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.grp_total_os as
    select  PRD_GRP
          , sum(LCY_TOT_OS) as GRP_TOTAL_OS
          , sum(case when RSME_FLG = 'Y' then LCY_TOT_OS else 0 end)
                                              as GRP_RSME_OS
    from WORK.new_loans
    group by PRD_GRP
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 5: Pro-rata allocation to each new loan
  ---------------------------------------------------------------------------
  General pool (all loans):
      GEN_ALLOC_COST  = (LCY_TOT_OS / GRP_TOTAL_OS) * GRP_GEN_COST
  RSME pool (RSME loans only; unallocated if no RSME loans in the group):
      RSME_ALLOC_COST = (LCY_TOT_OS / GRP_RSME_OS)  * GRP_RSME_COST
  ALLOCATED_COST = GEN_ALLOC_COST + RSME_ALLOC_COST
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.new_loans_allocated as
    select  n.PROC_DTE
          , n.AC_CODE
          , n.CIF_NO
          , n.BIZ_PRD_CODE
          , n.PRD_GRP
          , n.RSME_FLG
          , n.LCY_TOT_OS
          , s.GRP_TOTAL_OS
          , s.GRP_RSME_OS
          , g.GRP_GEN_COST
          , g.GRP_RSME_COST

          /* general pool share - every new loan participates */
          , case when s.GRP_TOTAL_OS > 0
                 then (n.LCY_TOT_OS / s.GRP_TOTAL_OS) * g.GRP_GEN_COST
                 else 0
            end as GEN_ALLOC_COST

          /* RSME pool share - RSME loans only; if the group has no RSME
             loans (GRP_RSME_OS = 0) the RSME cost stays unallocated */
          , case when n.RSME_FLG = 'Y' and s.GRP_RSME_OS > 0
                 then (n.LCY_TOT_OS / s.GRP_RSME_OS) * g.GRP_RSME_COST
                 else 0
            end as RSME_ALLOC_COST

          , calculated GEN_ALLOC_COST + calculated RSME_ALLOC_COST
                                              as ALLOCATED_COST
    from        WORK.new_loans       as n
    left join   WORK.grp_total_os    as s  on n.PRD_GRP = s.PRD_GRP
    left join   WORK.gl_cost_by_grp  as g  on n.PRD_GRP = g.PRD_GRP
    order by n.PRD_GRP, n.RSME_FLG, n.AC_CODE
    ;
quit;

/*--------------------------------------------------------------------------
  STEP 6: Drop intermediate WORK tables
  ---------------------------------------------------------------------------
  Keeps only the two final outputs:
    - WORK.NEW_LOANS_ALLOCATED  (final allocation table)
    - WORK.GL_COST_DETAIL       (GL movement at GL_AC_CODE granularity)
--------------------------------------------------------------------------*/
proc datasets library=WORK nolist;
    delete curr_loans
           prev_loans
           repriced
           rsme_cifs
           new_loans
           gl_cost_by_grp
           grp_total_os
           ;
quit;
