%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.rp(keep=AC_CODE REPRICE_FLAG);
    length AC_CODE $50 REPRICE_FLAG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE REPRICE_FLAG)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE REPRICE_FLAG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE REPRICE_FLAG)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE REPRICE_FLAG)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE REPRICE_FLAG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER REPRICE_FLAG
                            F_REPRICE_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER REPRICE_FLAG F_REPRICE_FLAG;
    length AC_CODE $50 REPRICE_FLAG $1 F_REPRICE_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rp");
        r.definekey("AC_CODE");
        r.definedata("REPRICE_FLAG");
        r.definedone();
    end;

    call missing(REPRICE_FLAG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    F_REPRICE_FLAG = REPRICE_FLAG;
run;

proc datasets library=WORK nolist;
    delete rp;
quit;
