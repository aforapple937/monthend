%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.v_ref(keep=DWH_AC_CODE ARREAR_NO);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE ARREAR_NO
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE ARREAR_NO MTH_ARREARS);
    retain PROC_DTE AC_CODE ARREAR_NO MTH_ARREARS;
    length DWH_AC_CODE $50;
    format ARREAR_NO MTH_ARREARS 6.;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash v(dataset:"WORK.v_ref");
        v.definekey("DWH_AC_CODE");
        v.definedata("ARREAR_NO");
        v.definedone();
    end;

    call missing(ARREAR_NO);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = v.find();

    MTH_ARREARS = coalesce(ARREAR_NO, 0);
run;

proc datasets library=WORK nolist;
    delete v_ref;
quit;
