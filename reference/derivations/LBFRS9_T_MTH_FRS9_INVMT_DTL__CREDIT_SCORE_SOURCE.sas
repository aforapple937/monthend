%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.rating(keep=DWH_AC_CODE RATING_MODEL_CODE);
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10;
    set LBDWH.T_DAL_BORR_AC_RATING_DTL(keep=PROC_DTE AC_CODE
                                            RATING_MODEL_CODE
                                       rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.invmt_derived(keep=PROC_DTE AC_CODE RSME_FLG RATING_MODEL_CODE CREDIT_SCORE_SOURCE);
    retain PROC_DTE AC_CODE RSME_FLG RATING_MODEL_CODE CREDIT_SCORE_SOURCE;
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10 CREDIT_SCORE_SOURCE $10;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                         RSME_FLG ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rating");
        r.definekey("DWH_AC_CODE");
        r.definedata("RATING_MODEL_CODE");
        r.definedone();
    end;

    call missing(RATING_MODEL_CODE, CREDIT_SCORE_SOURCE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = r.find();

    if strip(RSME_FLG) ne 'Y' then
    select (strip(RATING_MODEL_CODE));
        when ('CT') CREDIT_SCORE_SOURCE = 'CN';
        when ('LC') CREDIT_SCORE_SOURCE = 'LG';
        when ('MD') CREDIT_SCORE_SOURCE = 'MP';
        when ('MS') CREDIT_SCORE_SOURCE = 'MD';
        when ('RE') CREDIT_SCORE_SOURCE = 'DI';
        when ('SM') CREDIT_SCORE_SOURCE = 'SM';
        when ('CR') CREDIT_SCORE_SOURCE = 'XX';
        otherwise   CREDIT_SCORE_SOURCE = RATING_MODEL_CODE;
    end;
run;

proc datasets library=WORK nolist;
    delete rating;
quit;
