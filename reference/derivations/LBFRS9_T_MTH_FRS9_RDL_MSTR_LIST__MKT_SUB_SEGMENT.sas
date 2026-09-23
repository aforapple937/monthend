%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = MKT_SUB_SEGMENT;

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

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CUST_MKT_SUB_SEG MKT_SUB_SEGMENT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CUST_MKT_SUB_SEG MKT_SUB_SEGMENT &act_out;
    length MKT_SUB_SEGMENT $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CUST_MKT_SUB_SEG &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    select (strip(V_CUST_MKT_SUB_SEG));
        when ('1')  MKT_SUB_SEGMENT = 'SME BANKING';
        when ('2')  MKT_SUB_SEGMENT = 'BUSINESS BANKING';
        when ('3')  MKT_SUB_SEGMENT = 'CONSUMER';
        when ('11') MKT_SUB_SEGMENT = 'COMMERCIAL BANKING';
        when ('13') MKT_SUB_SEGMENT = 'GWB-CORPORATE BANK';
        when ('16') MKT_SUB_SEGMENT = 'GWB-GLOBAL MARKET';
        otherwise   call missing(MKT_SUB_SEGMENT);
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
