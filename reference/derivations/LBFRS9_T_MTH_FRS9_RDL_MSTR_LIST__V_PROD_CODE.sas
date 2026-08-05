%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prd(keep=AC_CODE PRD_CODE);
    length AC_CODE $50 PRD_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE PRD_CODE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE PRD_CODE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE PRD_CODE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE PRD_CODE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE PRD_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER PRD_CODE V_PROD_CODE);
    retain PROC_DTE V_ACCOUNT_NUMBER PRD_CODE V_PROD_CODE;
    length V_PROD_CODE $50 AC_CODE $50 PRD_CODE $50;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.prd");
        p.definekey("AC_CODE");
        p.definedata("PRD_CODE");
        p.definedone();
    end;

    call missing(PRD_CODE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = p.find();

    V_PROD_CODE = PRD_CODE;
run;

proc datasets library=WORK nolist;
    delete prd;
quit;
