%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER F_EXP_REVOLVING_FLAG
                            PROD_LV4 AMORTISED_CASH_IND);
    retain PROC_DTE V_ACCOUNT_NUMBER F_EXP_REVOLVING_FLAG PROD_LV4
           AMORTISED_CASH_IND;
    length AMORTISED_CASH_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             F_EXP_REVOLVING_FLAG PROD_LV4);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if strip(F_EXP_REVOLVING_FLAG) = 'N'
       and strip(PROD_LV4) in ('Auto', 'Term Loans')
        then AMORTISED_CASH_IND = 'Y';
    else AMORTISED_CASH_IND = 'N';
run;
