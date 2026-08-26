%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
                            N_EAD_AMOUNT_RCY DCF_AMT INDIVIDUAL_ALLOWANCE);
    retain PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
           N_EAD_AMOUNT_RCY DCF_AMT INDIVIDUAL_ALLOWANCE;
    format INDIVIDUAL_ALLOWANCE 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             V_IFRS_STAGE_CODE
                                             N_EAD_AMOUNT_RCY DCF_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(INDIVIDUAL_ALLOWANCE);

    if strip(V_IFRS_STAGE_CODE) = 'STAGE3' then
        INDIVIDUAL_ALLOWANCE = max(0, N_EAD_AMOUNT_RCY - DCF_AMT);
run;
