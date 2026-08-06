%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

proc sort data=LBDWH.T_MTH_CURCY_EXCHG
              (keep=PROC_DTE CURCY_CODE EXCHG_RT
               where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm))
          out=WORK.fx(drop=PROC_DTE) nodupkey;
    by CURCY_CODE;
run;

data WORK.drawn(keep=AC_CODE RCY_DRAWN_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE RCY_DRAWN_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_DRAWN_AMT
                            EXCHG_RT N_DRAWN_AMOUNT);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_DRAWN_AMT
           EXCHG_RT N_DRAWN_AMOUNT;
    format N_DRAWN_AMOUNT 24.3;

    if 0 then set WORK.drawn WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.drawn");
        d.definekey("AC_CODE");
        d.definedata("RCY_DRAWN_AMT");
        d.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(RCY_DRAWN_AMT, EXCHG_RT);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_d = d.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    if not missing(RCY_DRAWN_AMT) then
        N_DRAWN_AMOUNT = round(RCY_DRAWN_AMT * EXCHG_RT, 0.001);
run;

proc datasets library=WORK nolist;
    delete drawn fx;
quit;
