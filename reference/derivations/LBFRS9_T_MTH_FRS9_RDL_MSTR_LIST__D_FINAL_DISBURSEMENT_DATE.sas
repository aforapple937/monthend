%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = D_FINAL_DISBURSEMENT_DATE;

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

data WORK.disb(keep=AC_CODE FINAL_DISB_DTE);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE FINAL_DISB_DTE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER FINAL_DISB_DTE
                            D_FINAL_DISBURSEMENT_DATE &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER FINAL_DISB_DTE
           D_FINAL_DISBURSEMENT_DATE &act_out;
    length AC_CODE $50;
    format FINAL_DISB_DTE D_FINAL_DISBURSEMENT_DATE datetime20.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.disb");
        d.definekey("AC_CODE");
        d.definedata("FINAL_DISB_DTE");
        d.definedone();
    end;

    call missing(FINAL_DISB_DTE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = d.find();

    D_FINAL_DISBURSEMENT_DATE = FINAL_DISB_DTE;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if &tgt = ACTUAL                     then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete disb;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
