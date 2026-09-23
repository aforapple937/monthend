%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = F_RATING_OUTLOOK_WATCH;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.watch(keep=AC_CODE RATING_OUTLOOK_WATCH);
    length AC_CODE $50 RATING_OUTLOOK_WATCH $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE RATING_OUTLOOK_WATCH)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE RATING_OUTLOOK_WATCH)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE RATING_OUTLOOK_WATCH)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE RATING_OUTLOOK_WATCH)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE RATING_OUTLOOK_WATCH);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RATING_OUTLOOK_WATCH
                            F_RATING_OUTLOOK_WATCH &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER RATING_OUTLOOK_WATCH
           F_RATING_OUTLOOK_WATCH &act_out;
    length AC_CODE $50 RATING_OUTLOOK_WATCH $1 F_RATING_OUTLOOK_WATCH $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash w(dataset:"WORK.watch");
        w.definekey("AC_CODE");
        w.definedata("RATING_OUTLOOK_WATCH");
        w.definedone();
    end;

    call missing(RATING_OUTLOOK_WATCH);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = w.find();

    if missing(RATING_OUTLOOK_WATCH) then F_RATING_OUTLOOK_WATCH = 'N';
    else F_RATING_OUTLOOK_WATCH = RATING_OUTLOOK_WATCH;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete watch;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
