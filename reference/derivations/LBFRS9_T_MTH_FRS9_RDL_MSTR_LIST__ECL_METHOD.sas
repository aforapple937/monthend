%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
                            CURR_RATING ECL_METHOD);
    retain PROC_DTE V_ACCOUNT_NUMBER V_IFRS_STAGE_CODE
           CURR_RATING ECL_METHOD;
    length ECL_METHOD $255;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_IFRS_STAGE_CODE CURR_RATING);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if      V_IFRS_STAGE_CODE = 'STAGE3' then ECL_METHOD = 'Specific Provision Methodology';
    else if CURR_RATING       = 'UNRATED' then ECL_METHOD = 'Risk Sensitivity Method';
    else                                       ECL_METHOD = 'PD LGD Method';
run;
