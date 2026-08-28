%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.rating(keep=DWH_AC_CODE RATING_MODEL_CODE);
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10;
    set LBDWH.T_DAL_BORR_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING_MODEL_CODE
                                       rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.acdtl(keep=DWH_AC_CODE CIF_TYP_CODE);
    length DWH_AC_CODE $50 CIF_TYP_CODE $10;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE CIF_TYP_CODE
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.intrtg(keep=AC_CODE INTERNAL_RATING);
    length AC_CODE $50 INTERNAL_RATING $20;
    set LBFRS9.T_MTH_FRS9_AC_RATING_DTL(keep=PROC_DTE AC_CODE INTERNAL_RATING
                                             ORGL_CR_RATING_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ORGL_CR_RATING_FLG = 'N';
run;

data WORK.party(keep=CIF_NO MKT_SUB_SEG);
    length CIF_NO $50 MKT_SUB_SEG $15;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO MKT_SUB_SEG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.invmt_derived(keep=PROC_DTE AC_CODE RSME_FLG RATING_MODEL_CODE
                            CIF_TYP_CODE INTERNAL_RATING MKT_SUB_SEG CREDIT_SCORE_SOURCE);
    retain PROC_DTE AC_CODE RSME_FLG RATING_MODEL_CODE CIF_TYP_CODE
           INTERNAL_RATING MKT_SUB_SEG CREDIT_SCORE_SOURCE;
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10 CIF_TYP_CODE $10
           INTERNAL_RATING $20 MKT_SUB_SEG $15 CREDIT_SCORE_SOURCE $10;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                         CIF_NO RSME_FLG ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rating");
        r.definekey("DWH_AC_CODE");
        r.definedata("RATING_MODEL_CODE");
        r.definedone();

        declare hash a(dataset:"WORK.acdtl");
        a.definekey("DWH_AC_CODE");
        a.definedata("CIF_TYP_CODE");
        a.definedone();

        declare hash i(dataset:"WORK.intrtg");
        i.definekey("AC_CODE");
        i.definedata("INTERNAL_RATING");
        i.definedone();

        declare hash p(dataset:"WORK.party");
        p.definekey("CIF_NO");
        p.definedata("MKT_SUB_SEG");
        p.definedone();
    end;

    call missing(RATING_MODEL_CODE, CIF_TYP_CODE, INTERNAL_RATING, MKT_SUB_SEG,
                 CREDIT_SCORE_SOURCE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc_r = r.find();
    rc_a = a.find();
    rc_i = i.find();
    rc_p = p.find();

    if strip(RSME_FLG) ne 'Y' then do;

        if missing(RATING_MODEL_CODE) then do;
            if strip(CIF_TYP_CODE) in ('CLUB', 'COY', 'NBANKFI', 'SCHOOL',
                                       'OTHERS', 'NA', 'STATOTH', 'STATAUTH')
               and not missing(INTERNAL_RATING)
               and strip(INTERNAL_RATING) ne 'UNRATED'
               and strip(MKT_SUB_SEG) not in ('1', '3')
                then CREDIT_SCORE_SOURCE = 'XX';
        end;

        else
        select (strip(RATING_MODEL_CODE));
            when ('CT') CREDIT_SCORE_SOURCE = 'CN';
            when ('LC') CREDIT_SCORE_SOURCE = 'LG';
            when ('MD') CREDIT_SCORE_SOURCE = 'MP';
            when ('MS') CREDIT_SCORE_SOURCE = 'MD';
            when ('RE') CREDIT_SCORE_SOURCE = 'DI';
            when ('SB') CREDIT_SCORE_SOURCE = 'SM';
            when ('CR') CREDIT_SCORE_SOURCE = 'XX';
            when ('BK', 'FM') call missing(CREDIT_SCORE_SOURCE);
            otherwise   CREDIT_SCORE_SOURCE = RATING_MODEL_CODE;
        end;
    end;
run;

proc datasets library=WORK nolist;
    delete rating acdtl intrtg party;
quit;
