%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode = DERIVE;
%let tgt  = PRD_CODE;
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
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
    ;
quit;
proc sql;
    create table WORK.msg_ac as
    select distinct AC_CODE
    from LBDWH.T_MSG_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and MSG_TYP_CODE in ('225','XXX')
    ;
quit;
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
          %if %upcase(&mode) = CHECK %then %do;
          , l.PRD_CODE as ACT_PRD_CODE
          %end;
    from        LBFRS9.T_MTH_FRS9_LN_DTL as l
    left join   WORK.v_ref               as v   on l.ORIGINAL_ACCOUNT_NUMBER = v.AC_CODE
    left join   WORK.msg_ac              as m   on l.ORIGINAL_ACCOUNT_NUMBER = m.AC_CODE
    where l.PROC_DTE >= &rpt_dtm and l.PROC_DTE < &nxt_dtm
      and l.ACCT_STATUS_CODE = "Active"
    ;
quit;
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

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;
proc datasets library=WORK nolist;
    delete v_ref msg_ac ln_with_ref;
quit;
