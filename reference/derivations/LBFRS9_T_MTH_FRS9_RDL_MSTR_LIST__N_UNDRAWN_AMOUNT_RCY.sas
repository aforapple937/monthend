%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.undrawn(keep=AC_CODE RCY_UNDRAWN_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RCY_UNDRAWN_AMT
                            N_UNDRAWN_AMOUNT_RCY);
    retain PROC_DTE V_ACCOUNT_NUMBER RCY_UNDRAWN_AMT N_UNDRAWN_AMOUNT_RCY;
    length AC_CODE $50;
    format N_UNDRAWN_AMOUNT_RCY 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash u(dataset:"WORK.undrawn");
        u.definekey("AC_CODE");
        u.definedata("RCY_UNDRAWN_AMT");
        u.definedone();
    end;

    call missing(RCY_UNDRAWN_AMT, N_UNDRAWN_AMOUNT_RCY);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = u.find();

    N_UNDRAWN_AMOUNT_RCY = coalesce(RCY_UNDRAWN_AMT, 0);
run;

proc datasets library=WORK nolist;
    delete undrawn;
quit;
