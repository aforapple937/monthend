%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = CURR_RATING;

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

data WORK.curr_rtg(keep=AC_CODE RATING);
    length AC_CODE $50 RATING $20;
    set LBFRS9.T_MTH_FRS9_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING ORGL_CR_RATING_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ORGL_CR_RATING_FLG = 'N';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RATING CURR_RATING &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER RATING CURR_RATING &act_out;
    length CURR_RATING $20 AC_CODE $50 RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.curr_rtg");
        r.definekey("AC_CODE");
        r.definedata("RATING");
        r.definedone();
    end;

    call missing(RATING);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    if missing(RATING) then CURR_RATING = 'UNRATED';
    else CURR_RATING = RATING;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete curr_rtg;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
