%let rpt_mth = 31MAY2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
/*--------------------------------------------------------------------------
  STEP 1: V_T_MTH_AC_DTL logic fields for the reporting month
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.v_ref as
    select  AC_CODE
          , SYS_CODE
          , PRD_CODE
          , FAC_CODE
          , PURPOSE_CODE
          , BIZ_PRD_CODE
          , MI_PRD_CODE
    from LBDWH.V_T_MTH_AC_DTL
    where datepart(PROC_DTE) = &rpt_dt
    ;
quit;
/*--------------------------------------------------------------------------
  STEP 2: MSG accounts for the month (NOT ISNULL existence check)
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.msg_ac as
    select distinct AC_CODE
    from LBDWH.T_MSG_AC_DTL
    where datepart(PROC_DTE) = &rpt_dt
      and MSG_TYP_CODE in ('225','XXX')   
    ;
quit;
/*--------------------------------------------------------------------------
  STEP 3: LN_DTL keys + V logic fields (V_*) + MSG existence flag
--------------------------------------------------------------------------*/
proc sql;
    create table WORK.ln_with_ref as
    select  l.PROC_DTE
          , l.AC_CODE
          , v.SYS_CODE       as V_SYS_CODE
          , v.PRD_CODE       as V_PRD_CODE
          , v.FAC_CODE       as V_FAC_CODE
          , v.PURPOSE_CODE   as V_PURPOSE_CODE
          , v.BIZ_PRD_CODE   as V_BIZ_PRD_CODE
          , v.MI_PRD_CODE    as V_MI_PRD_CODE
          , case when m.AC_CODE is not missing then 1 else 0 end as IN_MSG
    from        LBFRS9.T_MTH_FRS9_LN_DTL as l
    left join   WORK.v_ref               as v   on l.ORIGINAL_ACCOUNT_NUMBER = v.AC_CODE
    left join   WORK.msg_ac              as m   on l.ORIGINAL_ACCOUNT_NUMBER = m.AC_CODE
    where datepart(l.PROC_DTE) = &rpt_dt and l.ACCT_STATUS_CODE = "Active"
    ;
quit;
/*--------------------------------------------------------------------------
  STEP 4: Apply the nested IIF logic -> PRD_CODE
--------------------------------------------------------------------------*/
data WORK.ln_derived;
    set WORK.ln_with_ref;
    length PRD_CODE $30;
    if V_SYS_CODE = 'RB' and V_PRD_CODE = 'A4' then
        PRD_CODE = 'SG_MYLN';
    else if ( (V_PRD_CODE = 'C1' and V_FAC_CODE = 'C1C')
           or (V_PRD_CODE = 'HT' and V_FAC_CODE = 'ST2')
           or (V_PRD_CODE = 'T2' and V_FAC_CODE = 'T2C') )
          and V_PURPOSE_CODE in ('IN','PU','WC') then
        PRD_CODE = 'SG_ETL';
    else if V_SYS_CODE = 'RB' and V_BIZ_PRD_CODE = 'TERMLN'
          and IN_MSG = 1 then
        PRD_CODE = 'SG_ETL';
    else if V_SYS_CODE = 'TS' and V_PRD_CODE = 'MLNETL' then
        PRD_CODE = 'SG_ETL';
    else if V_MI_PRD_CODE = 'RCL'
          and upcase(substr(AC_CODE,1,1)) = 'P' then
        PRD_CODE = 'SG_PWRCL';
    else
        PRD_CODE = 'SG_' || strip(V_BIZ_PRD_CODE);
run;
/*--------------------------------------------------------------------------
  STEP 5: Drop intermediates (keep WORK.LN_DERIVED)
--------------------------------------------------------------------------*/
proc datasets library=WORK nolist;
    delete v_ref msg_ac ln_with_ref;
quit;
