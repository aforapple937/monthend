%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.dflt(keep=AC_CODE DEFAULT_FLG);
    length AC_CODE $50 DEFAULT_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL    (keep=PROC_DTE AC_CODE DEFAULT_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL    (keep=PROC_DTE AC_CODE DEFAULT_FLG)
        LBFRS9.T_MTH_FRS9_INVMT_DTL (keep=PROC_DTE AC_CODE DEFAULT_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL    (keep=PROC_DTE AC_CODE DEFAULT_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER DEFAULT_FLG
                            F_EXPOSURE_DEFAULT_STATUS_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER DEFAULT_FLG
           F_EXPOSURE_DEFAULT_STATUS_FLAG;
    length AC_CODE $50 DEFAULT_FLG $1 F_EXPOSURE_DEFAULT_STATUS_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.dflt");
        d.definekey("AC_CODE");
        d.definedata("DEFAULT_FLG");
        d.definedone();
    end;

    call missing(DEFAULT_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = d.find();

    F_EXPOSURE_DEFAULT_STATUS_FLAG = DEFAULT_FLG;
run;

proc datasets library=WORK nolist;
    delete dflt;
quit;
