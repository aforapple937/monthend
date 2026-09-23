%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = N_LEDGER_BALANCE_AMT;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.ledg(keep=AC_CODE LEDGER_BALANCE_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE LEDGER_BALANCE_AMT)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE LEDGER_BALANCE_AMT)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE LEDGER_BALANCE_AMT)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE LEDGER_BALANCE_AMT)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE LEDGER_BALANCE_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER LEDGER_BALANCE_AMT
                            N_LEDGER_BALANCE_AMT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER LEDGER_BALANCE_AMT
           N_LEDGER_BALANCE_AMT &act_out;
    length AC_CODE $50;
    format N_LEDGER_BALANCE_AMT 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash l(dataset:"WORK.ledg");
        l.definekey("AC_CODE");
        l.definedata("LEDGER_BALANCE_AMT");
        l.definedone();
    end;

    call missing(LEDGER_BALANCE_AMT);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = l.find();

    N_LEDGER_BALANCE_AMT = coalesce(LEDGER_BALANCE_AMT, 0);

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACT_&tgt;
    %end;
run;

proc datasets library=WORK nolist;
    delete ledg;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.mstr_derived;
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
