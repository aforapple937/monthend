%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.fx(keep=CURCY_CODE EXCHG_RT);
    set LBDWH.T_MTH_CURCY_EXCHG(keep=PROC_DTE CURCY_CODE EXCHG_RT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.undrawn(keep=AC_CODE RCY_UNDRAWN_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE RCY_UNDRAWN_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_UNDRAWN_AMT
                            EXCHG_RT N_UNDRAWN_AMOUNT_RCY);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_UNDRAWN_AMT
           EXCHG_RT N_UNDRAWN_AMOUNT_RCY;
    format N_UNDRAWN_AMOUNT_RCY 24.3;

    if 0 then set WORK.undrawn WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash u(dataset:"WORK.undrawn");
        u.definekey("AC_CODE");
        u.definedata("RCY_UNDRAWN_AMT");
        u.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(RCY_UNDRAWN_AMT, EXCHG_RT, N_UNDRAWN_AMOUNT_RCY);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_u = u.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    RCY_UNDRAWN_AMT = coalesce(RCY_UNDRAWN_AMT, 0);
    if RCY_UNDRAWN_AMT = 0 then N_UNDRAWN_AMOUNT_RCY = 0;
    else N_UNDRAWN_AMOUNT_RCY = RCY_UNDRAWN_AMT * EXCHG_RT;
run;

proc datasets library=WORK nolist;
    delete undrawn fx;
quit;
