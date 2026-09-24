%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = F_UNCOND_CANCELLED_EXP_IND;

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

data WORK.unc(keep=AC_CODE UNCOND_CANCELLED_EXP_IND);
    length AC_CODE $50 UNCOND_CANCELLED_EXP_IND $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE UNCOND_CANCELLED_EXP_IND)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE UNCOND_CANCELLED_EXP_IND)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE UNCOND_CANCELLED_EXP_IND)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE UNCOND_CANCELLED_EXP_IND);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER UNCOND_CANCELLED_EXP_IND
                            F_UNCOND_CANCELLED_EXP_IND &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER UNCOND_CANCELLED_EXP_IND
           F_UNCOND_CANCELLED_EXP_IND &act_out;
    length F_UNCOND_CANCELLED_EXP_IND $1 AC_CODE $50 UNCOND_CANCELLED_EXP_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash u(dataset:"WORK.unc");
        u.definekey("AC_CODE");
        u.definedata("UNCOND_CANCELLED_EXP_IND");
        u.definedone();
    end;

    call missing(UNCOND_CANCELLED_EXP_IND);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = u.find();

    F_UNCOND_CANCELLED_EXP_IND = UNCOND_CANCELLED_EXP_IND;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete unc;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
