%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));

/* CUSTOMER_ID is the CIF_NO from the product input tables, prefixed with SG. */
data WORK.cif(keep=AC_CODE CIF_NO);
    length AC_CODE $50 CIF_NO $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CIF_NO)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CIF_NO)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE CIF_NO)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CIF_NO)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE CIF_NO);
    where datepart(PROC_DTE) = &rpt_dt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CIF_NO CUSTOMER_ID);
    retain PROC_DTE V_ACCOUNT_NUMBER CIF_NO CUSTOMER_ID;
    length CUSTOMER_ID $50 AC_CODE $50 CIF_NO $50;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash c(dataset:"WORK.cif");
        c.definekey("AC_CODE");
        c.definedata("CIF_NO");
        c.definedone();
    end;

    call missing(CIF_NO);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = c.find();

    if missing(CIF_NO) then call missing(CUSTOMER_ID);
    else CUSTOMER_ID = cats('SG', CIF_NO);
run;

proc datasets library=WORK nolist;
    delete cif;
quit;
