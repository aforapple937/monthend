%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = N_DRAWN_AMOUNT;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL DIFF;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.fx(keep=CURCY_CODE EXCHG_RT);
    set LBDWH.T_MTH_CURCY_EXCHG(keep=PROC_DTE CURCY_CODE EXCHG_RT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.drawn(keep=AC_CODE RCY_DRAWN_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE RCY_DRAWN_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_DRAWN_AMT
                            EXCHG_RT N_DRAWN_AMOUNT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_DRAWN_AMT
           EXCHG_RT N_DRAWN_AMOUNT &act_out;
    format N_DRAWN_AMOUNT 24.3;

    if 0 then set WORK.drawn WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE &act_keep &act_ren);
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

    call missing(RCY_DRAWN_AMT, EXCHG_RT, N_DRAWN_AMOUNT);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_d = d.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    RCY_DRAWN_AMT = coalesce(RCY_DRAWN_AMT, 0);
    if RCY_DRAWN_AMT = 0 then N_DRAWN_AMOUNT = 0;
    else N_DRAWN_AMOUNT = RCY_DRAWN_AMT * EXCHG_RT;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACTUAL;
    %end;
run;

proc datasets library=WORK nolist;
    delete drawn fx;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.mstr_derived;
    if missing(&tgt) and missing(ACTUAL) then delete;
    ABS_DIFF = abs(DIFF);
run;

proc means data=WORK.chk_var n nmiss max maxdec=12;
    var ABS_DIFF;
    title "&tgt - CHECK &rpt_mth - maximum absolute variance";
    label ABS_DIFF = "Absolute variance";
run;
title;

proc datasets library=WORK nolist;
    delete chk_var;
quit;
%end;
