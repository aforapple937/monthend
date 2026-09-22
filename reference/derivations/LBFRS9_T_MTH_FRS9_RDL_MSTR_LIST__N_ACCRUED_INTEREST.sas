%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_ACCRUED_INTEREST;
%let num_tol = 0.0005;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF MATCH;
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

data WORK.accr(keep=AC_CODE RCY_ACCRUED_INT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL    (keep=PROC_DTE AC_CODE RCY_ACCRUED_INT)
        LBFRS9.T_MTH_FRS9_INVMT_DTL (keep=PROC_DTE AC_CODE RCY_ACCRUED_INT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_ACCRUED_INT
                            EXCHG_RT N_ACCRUED_INTEREST &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_ACCRUED_INT
           EXCHG_RT N_ACCRUED_INTEREST &act_out;
    format N_ACCRUED_INTEREST 24.3;

    if 0 then set WORK.accr WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.accr");
        h.definekey("AC_CODE");
        h.definedata("RCY_ACCRUED_INT");
        h.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(RCY_ACCRUED_INT, EXCHG_RT);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_h = h.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    RCY_ACCRUED_INT = coalesce(RCY_ACCRUED_INT, 0);
    if RCY_ACCRUED_INT = 0 then N_ACCRUED_INTEREST = 0;
    else N_ACCRUED_INTEREST = RCY_ACCRUED_INT * EXCHG_RT;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        DIFF = &tgt - ACT_&tgt;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete accr fx;
quit;
