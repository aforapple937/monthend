%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let far_dtm = '31DEC9999:00:00:00'dt;

data WORK.matr(keep=AC_CODE SRC MATURITY_DTE);
    length AC_CODE $50 SRC $5;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE MATURITY_DTE
                                         in=in_ln)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE MATURITY_DTE
                                         in=in_cc)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE MATURITY_DTE
                                         in=in_inv)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE MATURITY_DTE
                                         in=in_gu)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE MATURITY_DTE
                                         in=in_od);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;

    if      in_ln  then SRC = 'LN';
    else if in_cc  then SRC = 'CC';
    else if in_inv then SRC = 'INVMT';
    else if in_gu  then SRC = 'GUAR';
    else if in_od  then SRC = 'OD';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER MATURITY_DTE
                            D_REVISED_MATURITY_DATE);
    retain PROC_DTE V_ACCOUNT_NUMBER MATURITY_DTE
           D_REVISED_MATURITY_DATE;
    length AC_CODE $50 SRC $5;
    format MATURITY_DTE D_REVISED_MATURITY_DATE datetime20.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash m(dataset:"WORK.matr");
        m.definekey("AC_CODE");
        m.definedata("SRC", "MATURITY_DTE");
        m.definedone();
    end;

    call missing(SRC, MATURITY_DTE, D_REVISED_MATURITY_DATE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = m.find();

    if not missing(SRC) and strip(SRC) ne 'CC' then
        D_REVISED_MATURITY_DATE = coalesce(MATURITY_DTE, &far_dtm);
run;

proc datasets library=WORK nolist;
    delete matr;
quit;
