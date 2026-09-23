%let rpt_mth  = 31AUG2026;
%let rpt_dt   = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm  = "&rpt_mth:00:00:00"dt;
%let nxt_dtm  = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = F_NEW_ACCT_FLG;

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

/* VARIANCE: around 50 accounts are present in the previous month yet still
   carry F_NEW_ACCT_FLG = Y. */

data WORK.prev(keep=V_ACCOUNT_NUMBER);
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER);
    where PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER F_NEW_ACCT_FLG &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER F_NEW_ACCT_FLG &act_out;
    length F_NEW_ACCT_FLG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.prev");
        p.definekey("V_ACCOUNT_NUMBER");
        p.definedone();
    end;

    call missing(F_NEW_ACCT_FLG);
    if p.check() ne 0 then F_NEW_ACCT_FLG = 'Y';

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prev;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
