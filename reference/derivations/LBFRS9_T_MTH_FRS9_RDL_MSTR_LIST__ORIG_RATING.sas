%let rpt_mth  = 31AUG2026;
%let rpt_dt   = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm  = "&rpt_mth:00:00:00"dt;
%let nxt_dtm  = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = ORIG_RATING;

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
%let prev_dt  = %sysfunc(intnx(month, &rpt_dt, -1, end));
%let prev_dtm = "%sysfunc(putn(&prev_dt, date9.)):00:00:00"dt;
%let prv_nxt  = "%sysfunc(putn(%eval(&prev_dt + 1), date9.)):00:00:00"dt;

data WORK.orig_rtg(keep=AC_CODE ORGL_RATING);
    length AC_CODE $50 ORGL_RATING $20;
    set LBFRS9.T_MTH_FRS9_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING ORGL_CR_RATING_FLG
                                        rename=(RATING=ORGL_RATING));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ORGL_CR_RATING_FLG = 'Y';
run;

data WORK.prev_orig(keep=V_ACCOUNT_NUMBER PREV_ORIG_RATING);
    length V_ACCOUNT_NUMBER $50 PREV_ORIG_RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_AC_DTL(keep=PROC_DTE UNIQUE_ID_NO ORIGINAL_RATING
                                     rename=(UNIQUE_ID_NO=V_ACCOUNT_NUMBER
                                             ORIGINAL_RATING=PREV_ORIG_RATING));
    where PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER ORGL_RATING PREV_ORIG_RATING
                            CURR_RATING ORIG_RATING &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER ORGL_RATING PREV_ORIG_RATING
           CURR_RATING ORIG_RATING &act_out;
    length ORIG_RATING $20 AC_CODE $50 ORGL_RATING $20 PREV_ORIG_RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CURR_RATING &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash o(dataset:"WORK.orig_rtg");
        o.definekey("AC_CODE");
        o.definedata("ORGL_RATING");
        o.definedone();

        declare hash p(dataset:"WORK.prev_orig");
        p.definekey("V_ACCOUNT_NUMBER");
        p.definedata("PREV_ORIG_RATING");
        p.definedone();
    end;

    call missing(ORGL_RATING, PREV_ORIG_RATING);
    AC_CODE = V_ACCOUNT_NUMBER;

    rc_o = o.find();
    rc_p = p.find();

    if rc_o = 0 and not missing(ORGL_RATING) and ORGL_RATING ne 'UNRATED' then
        ORIG_RATING = ORGL_RATING;
    else if rc_p = 0 and PREV_ORIG_RATING ne 'UNRATED' then
        ORIG_RATING = PREV_ORIG_RATING;
    else ORIG_RATING = CURR_RATING;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete orig_rtg prev_orig;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
