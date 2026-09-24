%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = F_EXP_REVOLVING_FLAG;

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

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_3 LEVEL_5);
    length V_PROD_CODE $50 LEVEL_3 $20 LEVEL_5 $100;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3 LEVEL_5
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
                            LEVEL_3 PROD_LV4 LEVEL_5 F_EXP_REVOLVING_FLAG &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
           LEVEL_3 PROD_LV4 LEVEL_5 F_EXP_REVOLVING_FLAG &act_out;
    length F_EXP_REVOLVING_FLAG $1 LEVEL_3 $20 LEVEL_5 $100;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_PROD_CODE PROD_LV4 &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_3", "LEVEL_5");
        h.definedone();
    end;

    call missing(LEVEL_3, LEVEL_5);
    rc = h.find();

    if strip(PROD_LV4) = 'Term Loans'
       or strip(LEVEL_5) = 'Hire Purchase'
       or strip(LEVEL_3) in ('Interbank Placement','Investments','Cash and STF')
        then F_EXP_REVOLVING_FLAG = 'N';
    else F_EXP_REVOLVING_FLAG = 'Y';

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prd_hier;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
