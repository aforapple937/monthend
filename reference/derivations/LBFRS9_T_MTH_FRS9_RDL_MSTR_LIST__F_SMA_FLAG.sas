%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.sma(keep=AC_CODE SM_FLG);
    length AC_CODE $50 SM_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE SM_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE SM_FLG)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE SM_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE SM_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER SM_FLG F_SMA_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER SM_FLG F_SMA_FLAG;
    length AC_CODE $50 SM_FLG $1 F_SMA_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.sma");
        s.definekey("AC_CODE");
        s.definedata("SM_FLG");
        s.definedone();
    end;

    call missing(SM_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();

    if missing(SM_FLG) then F_SMA_FLAG = 'N';
    else F_SMA_FLAG = SM_FLG;
run;

proc datasets library=WORK nolist;
    delete sma;
quit;
