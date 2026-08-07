%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.delq(keep=AC_CODE LAST_DELQ_DTE);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE LAST_DELQ_DTE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE LAST_DELQ_DTE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE LAST_DELQ_DTE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE LAST_DELQ_DTE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE LAST_DELQ_DTE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER LAST_DELQ_DTE
                            D_LAST_DELINQUENT_DATE);
    retain PROC_DTE V_ACCOUNT_NUMBER LAST_DELQ_DTE
           D_LAST_DELINQUENT_DATE;
    length AC_CODE $50;
    format LAST_DELQ_DTE D_LAST_DELINQUENT_DATE datetime20.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash q(dataset:"WORK.delq");
        q.definekey("AC_CODE");
        q.definedata("LAST_DELQ_DTE");
        q.definedone();
    end;

    call missing(LAST_DELQ_DTE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = q.find();

    D_LAST_DELINQUENT_DATE = LAST_DELQ_DTE;
run;

proc datasets library=WORK nolist;
    delete delq;
quit;
