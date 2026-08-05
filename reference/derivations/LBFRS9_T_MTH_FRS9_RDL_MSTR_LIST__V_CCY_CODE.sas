%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.ccy(keep=AC_CODE CURCY_CODE);
    length CURCY_CODE $3;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CURCY_CODE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CURCY_CODE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE CURCY_CODE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CURCY_CODE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE CURCY_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CURCY_CODE V_CCY_CODE);
    retain PROC_DTE V_ACCOUNT_NUMBER CURCY_CODE V_CCY_CODE;
    length V_CCY_CODE $3 AC_CODE $50 CURCY_CODE $3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.ccy");
        s.definekey("AC_CODE");
        s.definedata("CURCY_CODE");
        s.definedone();
    end;

    call missing(CURCY_CODE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();
    V_CCY_CODE = CURCY_CODE;
run;

proc datasets library=WORK nolist;
    delete ccy;
quit;
