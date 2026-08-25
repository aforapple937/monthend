%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.arr(keep=AC_CODE MTH_ARREARS);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE MTH_ARREARS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER MTH_ARREARS
                            N_MONTH_IN_ARREARS);
    retain PROC_DTE V_ACCOUNT_NUMBER MTH_ARREARS N_MONTH_IN_ARREARS;
    length AC_CODE $50;
    format MTH_ARREARS N_MONTH_IN_ARREARS 6.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.arr");
        a.definekey("AC_CODE");
        a.definedata("MTH_ARREARS");
        a.definedone();
    end;

    call missing(MTH_ARREARS);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = a.find();

    N_MONTH_IN_ARREARS = MTH_ARREARS;
run;

proc datasets library=WORK nolist;
    delete arr;
quit;
