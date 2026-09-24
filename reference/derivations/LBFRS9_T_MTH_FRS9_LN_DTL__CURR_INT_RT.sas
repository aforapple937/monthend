%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = CURR_INT_RT;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL DIFF;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.ac_ref(keep=DWH_AC_CODE BASE_RT VAR_RT);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE BASE_RT VAR_RT
                             rename=(AC_CODE = DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE BASE_RT VAR_RT CURR_INT_RT
                          &act_out);
    retain PROC_DTE AC_CODE BASE_RT VAR_RT CURR_INT_RT &act_out;
    length DWH_AC_CODE $50;
    format BASE_RT VAR_RT 20.9 CURR_INT_RT 13.6;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.ac_ref");
        a.definekey("DWH_AC_CODE");
        a.definedata("BASE_RT", "VAR_RT");
        a.definedone();
    end;

    call missing(BASE_RT, VAR_RT);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = a.find();

    CURR_INT_RT = (coalesce(BASE_RT, 0) + coalesce(VAR_RT, 0)) * 100;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACTUAL;
    %end;
run;

proc datasets library=WORK nolist;
    delete ac_ref;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.ln_derived;
    ABS_DIFF = abs(DIFF);
run;

proc means data=WORK.chk_var n nmiss max maxdec=12;
    var ABS_DIFF;
    title "&tgt - CHECK &rpt_mth - maximum absolute variance";
    label ABS_DIFF = "Absolute variance";
run;
title;

proc datasets library=WORK nolist;
    delete chk_var;
quit;
%end;
