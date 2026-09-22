%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_EXPOSURE_LIMIT;
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

data WORK.lmt(keep=AC_CODE EXPOSURE_LMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE SANCTIONED_LMT
                                         rename=(SANCTIONED_LMT=EXPOSURE_LMT))
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE SANCTIONED_LMT
                                         rename=(SANCTIONED_LMT=EXPOSURE_LMT))
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE RCY_CURR_CREDIT_LMT
                                         rename=(RCY_CURR_CREDIT_LMT=EXPOSURE_LMT))
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE EXPOSURE_LMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE EXPOSURE_LMT
                            EXCHG_RT N_EXPOSURE_LIMIT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE EXPOSURE_LMT
           EXCHG_RT N_EXPOSURE_LIMIT &act_out;
    format N_EXPOSURE_LIMIT 24.3;

    if 0 then set WORK.lmt WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash l(dataset:"WORK.lmt");
        l.definekey("AC_CODE");
        l.definedata("EXPOSURE_LMT");
        l.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(EXPOSURE_LMT, EXCHG_RT, N_EXPOSURE_LIMIT);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_l = l.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    EXPOSURE_LMT = coalesce(EXPOSURE_LMT, 0);
    if EXPOSURE_LMT = 0 then N_EXPOSURE_LIMIT = 0;
    else N_EXPOSURE_LIMIT = EXPOSURE_LMT * EXCHG_RT;

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
    delete lmt fx;
quit;
