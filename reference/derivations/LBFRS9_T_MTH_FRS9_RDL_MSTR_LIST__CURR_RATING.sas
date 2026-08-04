%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));

/* CURR_RATING sources from RATING on AC_RATING_DTL. An account carries up to two
   rating rows per month, distinguished by ORGL_CR_RATING_FLG: Y = origination,
   N = current. Filter to N for the current rating. Accounts with no current
   rating row, or a blank RATING, default to UNRATED. */
data WORK.curr_rtg(keep=AC_CODE RATING);
    length AC_CODE $50 RATING $20;
    set LBFRS9.T_MTH_FRS9_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING ORGL_CR_RATING_FLG);
    where datepart(PROC_DTE) = &rpt_dt and ORGL_CR_RATING_FLG = 'N';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RATING CURR_RATING);
    retain PROC_DTE V_ACCOUNT_NUMBER RATING CURR_RATING;
    length CURR_RATING $20 AC_CODE $50 RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.curr_rtg");
        r.definekey("AC_CODE");
        r.definedata("RATING");
        r.definedone();
    end;

    call missing(RATING);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    if missing(RATING) then CURR_RATING = 'UNRATED';
    else CURR_RATING = RATING;
run;

proc datasets library=WORK nolist;
    delete curr_rtg;
quit;
