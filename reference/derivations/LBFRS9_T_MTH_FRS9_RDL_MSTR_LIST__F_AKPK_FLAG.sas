%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.akpk(keep=AC_CODE AKPK_FLG);
    length AC_CODE $50 AKPK_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE AKPK_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE AKPK_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE AKPK_FLG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE AKPK_FLAG
                                         rename=(AKPK_FLAG=AKPK_FLG))
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE AKPK_FLAG
                                         rename=(AKPK_FLAG=AKPK_FLG));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER AKPK_FLG F_AKPK_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER AKPK_FLG F_AKPK_FLAG;
    length AC_CODE $50 AKPK_FLG $1 F_AKPK_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.akpk");
        a.definekey("AC_CODE");
        a.definedata("AKPK_FLG");
        a.definedone();
    end;

    call missing(AKPK_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = a.find();

    F_AKPK_FLAG = AKPK_FLG;
run;

proc datasets library=WORK nolist;
    delete akpk;
quit;
