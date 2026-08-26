%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME
                            SCALAR_TERM_STRUCTURE);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME SCALAR_TERM_STRUCTURE;
    length SCALAR_TERM_STRUCTURE $100;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS V_SEGMENT_NAME);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    SCALAR_TERM_STRUCTURE = V_SEGMENT_NAME;
run;
