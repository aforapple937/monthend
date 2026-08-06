%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

/* Observed: N_CUST_UTILISATION_LEVEL on RDL_MSTR_LIST comes through all blank,
   even though CUST_UTILISATION on the FRS9 product tables is populated. */

data WORK.util(keep=AC_CODE CUST_UTILISATION);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CUST_UTILISATION);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUST_UTILISATION
                            N_CUST_UTILISATION_LEVEL);
    retain PROC_DTE V_ACCOUNT_NUMBER CUST_UTILISATION
           N_CUST_UTILISATION_LEVEL;
    length AC_CODE $50;
    format N_CUST_UTILISATION_LEVEL 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash u(dataset:"WORK.util");
        u.definekey("AC_CODE");
        u.definedata("CUST_UTILISATION");
        u.definedone();
    end;

    call missing(CUST_UTILISATION);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = u.find();

    N_CUST_UTILISATION_LEVEL = CUST_UTILISATION;
run;

proc datasets library=WORK nolist;
    delete util;
quit;
