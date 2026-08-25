%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.matr(keep=AC_CODE REVISED_MATURITY_DATE);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE REVISED_MATURITY_DATE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER REVISED_MATURITY_DATE
                            D_REVISED_MATURITY_DATE);
    retain PROC_DTE V_ACCOUNT_NUMBER REVISED_MATURITY_DATE
           D_REVISED_MATURITY_DATE;
    length AC_CODE $50;
    format REVISED_MATURITY_DATE D_REVISED_MATURITY_DATE datetime20.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash m(dataset:"WORK.matr");
        m.definekey("AC_CODE");
        m.definedata("REVISED_MATURITY_DATE");
        m.definedone();
    end;

    call missing(REVISED_MATURITY_DATE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = m.find();

    D_REVISED_MATURITY_DATE = REVISED_MATURITY_DATE;
run;

proc datasets library=WORK nolist;
    delete matr;
quit;
