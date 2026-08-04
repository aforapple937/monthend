%let rpt_mth = 31MAY2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
/*--------------------------------------------------------------------------
  STEP 1: V_T_MTH_AC_DTL logic fields for the reporting month
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.v_ref as
    select  AC_CODE
          , RT_TYP_CODE
          , MI_PRD_CODE
          , PRD_CODE
    from LBDWH.V_T_MTH_AC_DTL
    where datepart(PROC_DTE) = &rpt_dt
    ;
quit;
/*--------------------------------------------------------------------------
  STEP 2: LN_DTL keys + V logic fields (V_*)
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.ln_with_ref as
    select  l.PROC_DTE
          , l.AC_CODE
          , v.RT_TYP_CODE   as V_RT_TYP_CODE
          , v.MI_PRD_CODE   as V_MI_PRD_CODE
          , v.PRD_CODE      as V_PRD_CODE
    from        LBFRS9.T_MTH_FRS9_LN_DTL as l
    left join   WORK.v_ref               as v   on l.ORIGINAL_ACCOUNT_NUMBER = v.AC_CODE
    where datepart(l.PROC_DTE) = &rpt_dt and l.ACCT_STATUS_CODE = "Active"
    ;
quit;
/*--------------------------------------------------------------------------
  STEP 3: Apply the nested IIF logic -> INT_TYP
--------------------------------------------------------------------------*/
data WORK.ln_derived;
    set WORK.ln_with_ref;
    length INT_TYP $20;
    if missing(V_RT_TYP_CODE) then
        INT_TYP = '';                        /* RT_TYP_CODE null -> null */
    else if substr(V_MI_PRD_CODE,1,2) = 'HP'
         or upcase(V_MI_PRD_CODE) in ('BLK','FLOORSTK')
         or V_PRD_CODE = 'M6' then
        INT_TYP = 'Fixed Rate';
    else
        INT_TYP = 'Other Adjustable';
run;
/*--------------------------------------------------------------------------
  STEP 4: Drop intermediates (keep WORK.LN_DERIVED)
--------------------------------------------------------------------------*/
proc datasets library=WORK nolist;
    delete v_ref ln_with_ref;
quit;
