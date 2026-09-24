%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = V_SECTOR_CATEGORY;

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

data WORK.party(keep=CUSTOMER_ID SECTOR_CAT);
    length CUSTOMER_ID $50 SECTOR_CAT $6;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO SECTOR_CAT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID SECTOR_CAT V_SECTOR_CATEGORY &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID SECTOR_CAT V_SECTOR_CATEGORY &act_out;
    length V_SECTOR_CATEGORY $20 SECTOR_CAT $6;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CUSTOMER_ID &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CUSTOMER_ID");
        p.definedata("SECTOR_CAT");
        p.definedone();
    end;

    call missing(SECTOR_CAT);
    rc = p.find();

    V_SECTOR_CATEGORY = SECTOR_CAT;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete party;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
