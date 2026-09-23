%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = IMPAIRED_FLAG;

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

data WORK.imp(keep=CUSTOMER_ID IMPAIRMENT_FLG);
    length CUSTOMER_ID $50 IMPAIRMENT_FLG $1;
    set LBFRS9.T_MTH_FRS9_TASC_PARTY_FEED(keep=PROC_DTE CIF_NO EXPOSURE_ID
                                               IMPAIRMENT_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and EXPOSURE_ID ne "Securities";
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID
                            IMPAIRMENT_FLG IMPAIRED_FLAG &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID IMPAIRMENT_FLG IMPAIRED_FLAG &act_out;
    length IMPAIRMENT_FLG $1 IMPAIRED_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS CUSTOMER_ID &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash i(dataset:"WORK.imp");
        i.definekey("CUSTOMER_ID");
        i.definedata("IMPAIRMENT_FLG");
        i.definedone();
    end;

    call missing(IMPAIRMENT_FLG);
    rc = i.find();

    IMPAIRED_FLAG = IMPAIRMENT_FLG;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete imp;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
