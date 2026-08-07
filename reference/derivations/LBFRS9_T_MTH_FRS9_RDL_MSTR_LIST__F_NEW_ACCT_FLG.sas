%let rpt_mth  = 31JUL2026;
%let rpt_dt   = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm  = "&rpt_mth:00:00:00"dt;
%let nxt_dtm  = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let prev_dt  = %sysfunc(intnx(month, &rpt_dt, -1, end));
%let prev_dtm = "%sysfunc(putn(&prev_dt, date9.)):00:00:00"dt;
%let prv_nxt  = "%sysfunc(putn(%eval(&prev_dt + 1), date9.)):00:00:00"dt;

data WORK.prev(keep=V_ACCOUNT_NUMBER);
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER);
    where PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER F_NEW_ACCT_FLG);
    retain PROC_DTE V_ACCOUNT_NUMBER F_NEW_ACCT_FLG;
    length F_NEW_ACCT_FLG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.prev");
        p.definekey("V_ACCOUNT_NUMBER");
        p.definedone();
    end;

    if p.check() = 0 then F_NEW_ACCT_FLG = 'N';
    else F_NEW_ACCT_FLG = 'Y';
run;

proc datasets library=WORK nolist;
    delete prev;
quit;
