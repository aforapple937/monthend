%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.rating(keep=AC_CODE RATING_MODEL_CODE);
    length AC_CODE $50 RATING_MODEL_CODE $10;
    set LBDWH.T_DAL_BORR_AC_RATING_DTL(keep=PROC_DTE AC_CODE
                                            RATING_MODEL_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.guar_derived(keep=PROC_DTE AC_CODE RATING_MODEL_CODE CREDIT_SCORE_SOURCE);
    retain PROC_DTE AC_CODE RATING_MODEL_CODE CREDIT_SCORE_SOURCE;
    length RATING_MODEL_CODE $10 CREDIT_SCORE_SOURCE $10;
    set LBFRS9.T_MTH_FRS9_GUARANTEE_DTL(keep=PROC_DTE AC_CODE ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rating");
        r.definekey("AC_CODE");
        r.definedata("RATING_MODEL_CODE");
        r.definedone();
    end;

    call missing(RATING_MODEL_CODE);
    rc = r.find();

    CREDIT_SCORE_SOURCE = RATING_MODEL_CODE;
run;

proc datasets library=WORK nolist;
    delete rating;
quit;
