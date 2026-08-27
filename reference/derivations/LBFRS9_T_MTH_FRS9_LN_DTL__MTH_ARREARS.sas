%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.v_ref(keep=DWH_AC_CODE ARREAR_NO SYS_CODE CIF_TYP_CODE CR_STS_CODE);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE ARREAR_NO SYS_CODE
                                  CIF_TYP_CODE CR_STS_CODE
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE SYS_CODE CIF_TYP_CODE CR_STS_CODE
                          ARREAR_NO MTH_ARREARS);
    retain PROC_DTE AC_CODE SYS_CODE CIF_TYP_CODE CR_STS_CODE ARREAR_NO
           MTH_ARREARS;
    length DWH_AC_CODE $50;
    format ARREAR_NO MTH_ARREARS 6.;

    if 0 then set WORK.v_ref;

    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash v(dataset:"WORK.v_ref");
        v.definekey("DWH_AC_CODE");
        v.definedata("ARREAR_NO", "SYS_CODE", "CIF_TYP_CODE", "CR_STS_CODE");
        v.definedone();
    end;

    call missing(ARREAR_NO, SYS_CODE, CIF_TYP_CODE, CR_STS_CODE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = v.find();

    /* VARIANCE: only the fallback arm is implemented. The full expression is

           IIF( SYS_CODE = 'TS'
                AND IN(CIF_TYP_CODE,'INDV','STAFF')
                AND CR_STS_CODE = '2'
                AND NOT ISNULL(:LKP.LKP_T_FRS9_PRD_MSTR_TERM_LOANS(v_PRD_CODE)),
                2,
                DECODE(ARREAR_NO,NULL,0,ARREAR_NO) )

       so a TS individual or staff account at credit status 2 whose product
       is found by the lookup is forced to 2 rather than taking ARREAR_NO.
       What LKP_T_FRS9_PRD_MSTR_TERM_LOANS resolves to is not known, so that
       arm is left out. SYS_CODE, CIF_TYP_CODE and CR_STS_CODE are carried on
       the output to size the population the missing arm would affect. */
    MTH_ARREARS = coalesce(ARREAR_NO, 0);
run;

proc datasets library=WORK nolist;
    delete v_ref;
quit;
