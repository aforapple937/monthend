%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = V_CUST_MKT_SEG;

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

data WORK.party(keep=CUSTOMER_ID MKT_SEG);
    length CUSTOMER_ID $50 MKT_SEG $15;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO MKT_SEG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID MKT_SEG V_CUST_MKT_SEG &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID MKT_SEG V_CUST_MKT_SEG &act_out;
    length V_CUST_MKT_SEG $60 MKT_SEG $15;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CUSTOMER_ID &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CUSTOMER_ID");
        p.definedata("MKT_SEG");
        p.definedone();
    end;

    call missing(MKT_SEG);
    rc = p.find();

    V_CUST_MKT_SEG = MKT_SEG;

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
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
