%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_FACE_VALUE;
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

data WORK.face(keep=AC_CODE RCY_FACE_VAL_AMT);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE RCY_FACE_VAL_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_FACE_VAL_AMT
                            EXCHG_RT N_FACE_VALUE &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CCY_CODE RCY_FACE_VAL_AMT
           EXCHG_RT N_FACE_VALUE &act_out;
    format N_FACE_VALUE 24.3;

    if 0 then set WORK.face WORK.fx;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CCY_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash v(dataset:"WORK.face");
        v.definekey("AC_CODE");
        v.definedata("RCY_FACE_VAL_AMT");
        v.definedone();

        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(RCY_FACE_VAL_AMT, EXCHG_RT, N_FACE_VALUE);

    AC_CODE = V_ACCOUNT_NUMBER;
    rc_v = v.find();

    CURCY_CODE = V_CCY_CODE;
    rc_f = f.find();

    RCY_FACE_VAL_AMT = coalesce(RCY_FACE_VAL_AMT, 0);
    if RCY_FACE_VAL_AMT = 0 then N_FACE_VALUE = 0;
    else N_FACE_VALUE = RCY_FACE_VAL_AMT * EXCHG_RT;

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
    delete face fx;
quit;
