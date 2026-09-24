%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = INDIVIDUAL_ALLOWANCE;

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

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
                            N_EAD_AMOUNT_RCY DCF_AMT INDIVIDUAL_ALLOWANCE &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
           N_EAD_AMOUNT_RCY DCF_AMT INDIVIDUAL_ALLOWANCE &act_out;
    format INDIVIDUAL_ALLOWANCE 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             V_IFRS_STAGE_CODE
                                             N_EAD_AMOUNT_RCY DCF_AMT &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(INDIVIDUAL_ALLOWANCE);

    if strip(V_IFRS_STAGE_CODE) = 'STAGE3' and not missing(DCF_AMT) then
        INDIVIDUAL_ALLOWANCE = max(0, N_EAD_AMOUNT_RCY - DCF_AMT);

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACTUAL;
    %end;
run;

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
