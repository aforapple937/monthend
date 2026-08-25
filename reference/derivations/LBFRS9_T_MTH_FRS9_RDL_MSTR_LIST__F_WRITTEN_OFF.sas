%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.wo(keep=AC_CODE WO_FLG);
    length AC_CODE $50 WO_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE WO_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE WO_FLG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE WO_FLG)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE WO_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE WO_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER WO_FLG F_WRITTEN_OFF);
    retain PROC_DTE V_ACCOUNT_NUMBER WO_FLG F_WRITTEN_OFF;
    length AC_CODE $50 WO_FLG $1 F_WRITTEN_OFF $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash w(dataset:"WORK.wo");
        w.definekey("AC_CODE");
        w.definedata("WO_FLG");
        w.definedone();
    end;

    call missing(WO_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = w.find();

    F_WRITTEN_OFF = WO_FLG;
run;

proc datasets library=WORK nolist;
    delete wo;
quit;
