%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));

/* CORPORATE_SCORECARD sources from the credit-score-source field on the product
   input tables. Four tables (LN, CC, INVMT, GUARANTEE) carry CREDIT_SCORE_SOURCE;
   OD carries the equivalent under ORGL_EXT_CREDIT_SCORE_SOURCE. Both are kept as
   separate columns; an account appears in only one input table, so exactly one of
   them is populated and CORPORATE_SCORECARD takes whichever it is. */
data WORK.credit_src(keep=AC_CODE CREDIT_SCORE_SOURCE ORGL_EXT_CREDIT_SCORE_SOURCE);
    length CREDIT_SCORE_SOURCE $10 ORGL_EXT_CREDIT_SCORE_SOURCE $40;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE ORGL_EXT_CREDIT_SCORE_SOURCE);
    where datepart(PROC_DTE) = &rpt_dt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CREDIT_SCORE_SOURCE
                            ORGL_EXT_CREDIT_SCORE_SOURCE CORPORATE_SCORECARD);
    retain PROC_DTE V_ACCOUNT_NUMBER CREDIT_SCORE_SOURCE
           ORGL_EXT_CREDIT_SCORE_SOURCE CORPORATE_SCORECARD;
    length CORPORATE_SCORECARD $20 AC_CODE $50
           CREDIT_SCORE_SOURCE $10 ORGL_EXT_CREDIT_SCORE_SOURCE $40;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.credit_src");
        s.definekey("AC_CODE");
        s.definedata("CREDIT_SCORE_SOURCE","ORGL_EXT_CREDIT_SCORE_SOURCE");
        s.definedone();
    end;

    call missing(CREDIT_SCORE_SOURCE, ORGL_EXT_CREDIT_SCORE_SOURCE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();
    CORPORATE_SCORECARD = coalescec(CREDIT_SCORE_SOURCE, ORGL_EXT_CREDIT_SCORE_SOURCE);
run;

proc datasets library=WORK nolist;
    delete credit_src;
quit;
