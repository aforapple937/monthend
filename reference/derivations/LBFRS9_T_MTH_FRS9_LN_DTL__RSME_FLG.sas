%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = RSME_FLG;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.party(keep=CIF_NO MKT_SUB_SEG_DESC);
    length CIF_NO $50 MKT_SUB_SEG_DESC $60;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO MKT_SUB_SEG_DESC);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE CIF_NO MKT_SUB_SEG_DESC RSME_FLG &act_out);
    retain PROC_DTE AC_CODE CIF_NO MKT_SUB_SEG_DESC RSME_FLG &act_out;
    length MKT_SUB_SEG_DESC $60 RSME_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE CIF_NO
                                      ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CIF_NO");
        p.definedata("MKT_SUB_SEG_DESC");
        p.definedone();
    end;

    call missing(MKT_SUB_SEG_DESC);
    rc = p.find();

    if strip(MKT_SUB_SEG_DESC) = 'CFS-SME' then RSME_FLG = 'Y';
    else RSME_FLG = 'N';

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete party;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.ln_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
