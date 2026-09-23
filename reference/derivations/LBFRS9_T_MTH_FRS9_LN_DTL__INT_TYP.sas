%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode = CHECK;
%let tgt  = INT_TYP;
proc sql;
    create table WORK.v_ref as
    select  AC_CODE
          , RT_TYP_CODE
          , MI_PRD_CODE
          , PRD_CODE
    from LBDWH.V_T_MTH_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
    ;
quit;
proc sql;
    create table WORK.ln_with_ref as
    select  l.PROC_DTE
          , l.AC_CODE
          , v.RT_TYP_CODE   as V_RT_TYP_CODE
          , v.MI_PRD_CODE   as V_MI_PRD_CODE
          , v.PRD_CODE      as V_PRD_CODE
          %if %upcase(&mode) = CHECK %then %do;
          , l.INT_TYP as ACT_INT_TYP
          %end;
    from        LBFRS9.T_MTH_FRS9_LN_DTL as l
    left join   WORK.v_ref               as v   on l.ORIGINAL_ACCOUNT_NUMBER = v.AC_CODE
    where l.PROC_DTE >= &rpt_dtm and l.PROC_DTE < &nxt_dtm
      and l.ACCT_STATUS_CODE = "Active"
    ;
quit;
data WORK.ln_derived;
    set WORK.ln_with_ref;
    length INT_TYP $20;
    if missing(V_RT_TYP_CODE) then
        INT_TYP = '';
    else if substr(V_MI_PRD_CODE,1,2) = 'HP'
         or upcase(V_MI_PRD_CODE) in ('BLK','FLOORSTK')
         or V_PRD_CODE = 'M6' then
        INT_TYP = 'Fixed Rate';
    else
        INT_TYP = 'Other Adjustable';

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;
proc datasets library=WORK nolist;
    delete v_ref ln_with_ref;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.ln_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
