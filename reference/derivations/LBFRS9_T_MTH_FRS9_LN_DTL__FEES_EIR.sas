%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = FEES_EIR;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.ln_derived(keep=PROC_DTE AC_CODE FEES_EIR &act_out);
    retain PROC_DTE AC_CODE FEES_EIR &act_out;
    format FEES_EIR 24.3;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ACCT_STATUS_CODE
                                      &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    /* Not populated - FEES_EIR is left blank for every account. */
    call missing(FEES_EIR);

    %if %upcase(&mode) = CHECK %then %do;
        /* The derived value is always missing, so a variance is meaningless -
           the only question is whether the actual is missing as well. */
        length MATCH $1;
        if missing(ACTUAL) then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.ln_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
