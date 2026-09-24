%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = CREDIT_SCORE_SOURCE;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.rating(keep=DWH_AC_CODE RATING_MODEL_CODE);
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10;
    set LBDWH.T_DAL_BORR_AC_RATING_DTL(keep=PROC_DTE AC_CODE RATING_MODEL_CODE
                                       rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.cif(keep=CIF_NO CIF_TYP_CODE);
    length CIF_NO $50 CIF_TYP_CODE $10;
    set LBDWH.V_T_CIF_MSTR(keep=CIF_NO CIF_TYP_CODE);
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

data WORK.invmt_derived(keep=PROC_DTE AC_CODE PRD_CODE RSME_FLG
                             RATING_MODEL_CODE CIF_TYP_CODE INTERNAL_RATING
                             MKT_SUB_SEG CREDIT_SCORE_SOURCE &act_out);
    retain PROC_DTE AC_CODE PRD_CODE RSME_FLG RATING_MODEL_CODE CIF_TYP_CODE
           INTERNAL_RATING MKT_SUB_SEG CREDIT_SCORE_SOURCE &act_out;
    length DWH_AC_CODE $50 RATING_MODEL_CODE $10 CIF_TYP_CODE $10
           INTERNAL_RATING $20 MKT_SUB_SEG $15 CREDIT_SCORE_SOURCE $10;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                         CIF_NO PRD_CODE RSME_FLG
                                         ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rating");
        r.definekey("DWH_AC_CODE");
        r.definedata("RATING_MODEL_CODE");
        r.definedone();

        declare hash a(dataset:"WORK.cif");
        a.definekey("CIF_NO");
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

    /* NOTE: SG_NOSTRO accounts follow a different logic, not covered here.
       PRD_CODE is carried on the output so those rows can be isolated. */
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

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete rating cif intrtg party;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.invmt_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
