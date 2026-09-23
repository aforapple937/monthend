%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = LEDGER_BALANCE_AMT;

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

data WORK.ac_ref(keep=DWH_AC_CODE AC_STS_CODE RCY_TOT_OS REM_INST_AMT
                      RCY_INT_OS);
    length DWH_AC_CODE $50 AC_STS_CODE $1;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE AC_STS_CODE RCY_TOT_OS
                                  REM_INST_AMT RCY_INT_OS
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.fx(keep=CURCY_CODE EXCHG_RT);
    set LBDWH.T_MTH_CURCY_EXCHG(keep=PROC_DTE CURCY_CODE EXCHG_RT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.od_derived(keep=PROC_DTE AC_CODE CURCY_CODE AC_STS_CODE RCY_TOT_OS
                          REM_INST_AMT RCY_INT_OS EXCHG_RT LEDGER_BALANCE_AMT &act_out);
    retain PROC_DTE AC_CODE CURCY_CODE AC_STS_CODE RCY_TOT_OS REM_INST_AMT
           RCY_INT_OS EXCHG_RT LEDGER_BALANCE_AMT &act_out;
    length DWH_AC_CODE $50 AC_STS_CODE $1;
    format LEDGER_BALANCE_AMT 24.3;
    set LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      CURCY_CODE ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.ac_ref");
        a.definekey("DWH_AC_CODE");
        a.definedata("AC_STS_CODE", "RCY_TOT_OS", "REM_INST_AMT", "RCY_INT_OS");
        a.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(AC_STS_CODE, RCY_TOT_OS, REM_INST_AMT, RCY_INT_OS, EXCHG_RT);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc_a = a.find();
    rc_f = f.find();

    if strip(AC_STS_CODE) = '2' then LEDGER_BALANCE_AMT = 0;
    else do;
        if not missing(RCY_TOT_OS) and RCY_TOT_OS < 0 then _os = abs(RCY_TOT_OS);
        else _os = 0;

        LEDGER_BALANCE_AMT = (_os + coalesce(REM_INST_AMT, 0)
                                  + coalesce(RCY_INT_OS, 0)) * EXCHG_RT;
    end;

    drop _os;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACT_&tgt;
    %end;
run;

proc datasets library=WORK nolist;
    delete ac_ref fx;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.od_derived;
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
