%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.rel(keep=AC_CODE RELEASE_TYPE_CD);
    length AC_CODE $50 RELEASE_TYPE_CD $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE RELEASE_TYPE_CD);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RELEASE_TYPE_CD
                            V_RELEASE_TYPE_CD);
    retain PROC_DTE V_ACCOUNT_NUMBER RELEASE_TYPE_CD V_RELEASE_TYPE_CD;
    length V_RELEASE_TYPE_CD $1 AC_CODE $50 RELEASE_TYPE_CD $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rel");
        r.definekey("AC_CODE");
        r.definedata("RELEASE_TYPE_CD");
        r.definedone();
    end;

    call missing(RELEASE_TYPE_CD);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    V_RELEASE_TYPE_CD = RELEASE_TYPE_CD;
run;

proc datasets library=WORK nolist;
    delete rel;
quit;
