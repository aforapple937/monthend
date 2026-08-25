%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.emp(keep=AC_CODE EMPLOYEE_FLG);
    length AC_CODE $50 EMPLOYEE_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE EMPLOYEE_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL(keep=PROC_DTE AC_CODE EMPLOYEE_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE EMPLOYEE_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER EMPLOYEE_FLG
                            F_EMP_ACCT_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER EMPLOYEE_FLG F_EMP_ACCT_FLAG;
    length AC_CODE $50 EMPLOYEE_FLG $1 F_EMP_ACCT_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash e(dataset:"WORK.emp");
        e.definekey("AC_CODE");
        e.definedata("EMPLOYEE_FLG");
        e.definedone();
    end;

    call missing(EMPLOYEE_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = e.find();

    F_EMP_ACCT_FLAG = EMPLOYEE_FLG;
run;

proc datasets library=WORK nolist;
    delete emp;
quit;
