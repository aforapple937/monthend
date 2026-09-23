%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = F_RESTRUCTURED_IND;

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

data WORK.restr(keep=AC_CODE RESTRUCTURED_FLG);
    length AC_CODE $50 RESTRUCTURED_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL    (keep=PROC_DTE AC_CODE RESTRUCTURED_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL    (keep=PROC_DTE AC_CODE RESTRUCTURED_FLG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL (keep=PROC_DTE AC_CODE RESTRUCTURED_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL    (keep=PROC_DTE AC_CODE RESTRUCTURED_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RESTRUCTURED_FLG
                            F_RESTRUCTURED_IND &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER RESTRUCTURED_FLG F_RESTRUCTURED_IND &act_out;
    length AC_CODE $50 RESTRUCTURED_FLG $1 F_RESTRUCTURED_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.restr");
        r.definekey("AC_CODE");
        r.definedata("RESTRUCTURED_FLG");
        r.definedone();
    end;

    call missing(RESTRUCTURED_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    F_RESTRUCTURED_IND = RESTRUCTURED_FLG;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete restr;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
