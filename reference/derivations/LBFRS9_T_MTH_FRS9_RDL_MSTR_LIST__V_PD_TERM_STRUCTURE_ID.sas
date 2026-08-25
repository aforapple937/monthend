%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
                            V_PD_TERM_STRUCTURE_ID);
    retain PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
           V_PD_TERM_STRUCTURE_ID;
    length V_PD_TERM_STRUCTURE_ID $40;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             ECL_METHOD V_SEGMENT_NAME);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(V_PD_TERM_STRUCTURE_ID);

    if strip(ECL_METHOD) = 'PD LGD Method'
       and strip(V_SEGMENT_NAME) in ('SG_Bank', 'SG_CreditCard',
                                     'SG_EquityTermLoan', 'SG_HirePurchase',
                                     'SG_Housing', 'SG_IRRS', 'SG_Non-Retail',
                                     'SG_ProjectFinance', 'SG_RSME',
                                     'SG_Sovereign')
        then V_PD_TERM_STRUCTURE_ID = strip(V_SEGMENT_NAME);
run;
