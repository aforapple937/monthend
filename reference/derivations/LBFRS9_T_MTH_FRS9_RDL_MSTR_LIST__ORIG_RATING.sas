%let rpt_mth  = 30JUN2026;
%let rpt_dt   = %sysfunc(inputn(&rpt_mth, date9.));
%let prev_dt  = %sysfunc(intnx(month, &rpt_dt, -1, end));

/* ORIG_RATING is resolved in three steps, in order:
     1. RATING from AC_RATING_DTL where ORGL_CR_RATING_FLG = Y (the origination
        rating), if it is neither blank nor UNRATED.
     2. Otherwise: the prior month's ORIGINAL_RATING on RDL_AC_DTL, if present
        and not UNRATED.
     3. Otherwise: the current month's CURR_RATING on the master list. */
data WORK.orig_rtg(keep=AC_CODE ORGL_RATING);
    length AC_CODE $50 ORGL_RATING $20;
    set LBFRS9.T_MTH_FRS9_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING ORGL_CR_RATING_FLG
                                        rename=(RATING=ORGL_RATING));
    where datepart(PROC_DTE) = &rpt_dt and ORGL_CR_RATING_FLG = 'Y';
run;

data WORK.prev_orig(keep=V_ACCOUNT_NUMBER PREV_ORIG_RATING);
    length V_ACCOUNT_NUMBER $50 PREV_ORIG_RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_AC_DTL(keep=PROC_DTE UNIQUE_ID_NO ORIGINAL_RATING
                                     rename=(UNIQUE_ID_NO=V_ACCOUNT_NUMBER
                                             ORIGINAL_RATING=PREV_ORIG_RATING));
    where datepart(PROC_DTE) = &prev_dt;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER ORGL_RATING PREV_ORIG_RATING
                            CURR_RATING ORIG_RATING);
    retain PROC_DTE V_ACCOUNT_NUMBER ORGL_RATING PREV_ORIG_RATING
           CURR_RATING ORIG_RATING;
    length ORIG_RATING $20 AC_CODE $50 ORGL_RATING $20 PREV_ORIG_RATING $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CURR_RATING);
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash o(dataset:"WORK.orig_rtg");
        o.definekey("AC_CODE");
        o.definedata("ORGL_RATING");
        o.definedone();

        declare hash p(dataset:"WORK.prev_orig");
        p.definekey("V_ACCOUNT_NUMBER");
        p.definedata("PREV_ORIG_RATING");
        p.definedone();
    end;

    call missing(ORGL_RATING, PREV_ORIG_RATING);
    AC_CODE = V_ACCOUNT_NUMBER;

    rc_o = o.find();
    rc_p = p.find();

    if rc_o = 0 and not missing(ORGL_RATING) and ORGL_RATING ne 'UNRATED' then
        ORIG_RATING = ORGL_RATING;
    else if rc_p = 0 and PREV_ORIG_RATING ne 'UNRATED' then
        ORIG_RATING = PREV_ORIG_RATING;
    else ORIG_RATING = CURR_RATING;
run;

proc datasets library=WORK nolist;
    delete orig_rtg prev_orig;
quit;
