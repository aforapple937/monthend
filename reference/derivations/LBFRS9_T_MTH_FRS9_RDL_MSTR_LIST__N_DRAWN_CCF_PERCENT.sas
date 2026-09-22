%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_DRAWN_CCF_PERCENT;
%let num_tol = 0.0005;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_2);
    length V_PROD_CODE $50 LEVEL_2 $20;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_2
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
                            LEVEL_2 CE_TYPE N_DRAWN_CCF_PERCENT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
           LEVEL_2 CE_TYPE N_DRAWN_CCF_PERCENT &act_out;
    length LEVEL_2 $20;
    format N_DRAWN_CCF_PERCENT 17.11;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_SEGMENT_TYPE V_PROD_CODE CE_TYPE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_2");
        h.definedone();
    end;

    call missing(LEVEL_2, N_DRAWN_CCF_PERCENT);
    rc = h.find();

    if strip(V_SEGMENT_TYPE) = 'NON RETAIL' and strip(LEVEL_2) = 'Trade' then
    select (strip(CE_TYPE));
        when ('230') N_DRAWN_CCF_PERCENT = 0.5;
        when ('232') N_DRAWN_CCF_PERCENT = 1;
        when ('238') N_DRAWN_CCF_PERCENT = 0.2;
        otherwise;
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        DIFF = &tgt - ACT_&tgt;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prd_hier;
quit;
