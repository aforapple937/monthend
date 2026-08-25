%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.shf(keep=AC_CODE SHORTFALL_FLAG);
    length AC_CODE $50 SHORTFALL_FLAG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE SHORTFALL_FLAG)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE SHORTFALL_FLAG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE SHORTFALL_FLAG)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE SHORTFALL_FLAG)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE SHORTFALL_FLAG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER SHORTFALL_FLAG
                            F_SHORTFALL_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER SHORTFALL_FLAG F_SHORTFALL_FLAG;
    length AC_CODE $50 SHORTFALL_FLAG $1 F_SHORTFALL_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.shf");
        s.definekey("AC_CODE");
        s.definedata("SHORTFALL_FLAG");
        s.definedone();
    end;

    call missing(SHORTFALL_FLAG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();

    F_SHORTFALL_FLAG = SHORTFALL_FLAG;
run;

proc datasets library=WORK nolist;
    delete shf;
quit;
